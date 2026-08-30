"""
Vertically scale an ECS service by registering a new task definition size.

Triggered by CloudWatch alarms via SNS. Alarm names ending in -high step up
the ladder; names ending in -low step down. If we are already at the edge of
the ladder we log and exit without changing anything.
"""

from __future__ import annotations

import json
import logging
import os
from typing import Any

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ecs = boto3.client("ecs")

CLUSTER_NAME = os.environ["CLUSTER_NAME"]
SERVICE_NAME = os.environ["SERVICE_NAME"]

# Ordered from smallest to largest. Change via env if you need different sizes.
DEFAULT_LADDER = [
    {"cpu": 256, "memory": 512},
    {"cpu": 512, "memory": 1024},
    {"cpu": 1024, "memory": 2048},
]


def _ladder() -> list[dict[str, int]]:
    raw = os.environ.get("SIZE_LADDER")
    if not raw:
        return DEFAULT_LADDER
    return json.loads(raw)


def _parse_sns_alarm(event: dict[str, Any]) -> dict[str, Any]:
    """Pull the CloudWatch alarm payload out of the SNS wrapper."""
    record = event["Records"][0]
    message = record["Sns"]["Message"]
    if isinstance(message, str):
        return json.loads(message)
    return message


def _direction_from_alarm(alarm_name: str, new_state: str) -> str | None:
    """
    Only act when the alarm is ALARM (not OK/INSUFFICIENT_DATA).
    -high means scale up, -low means scale down.
    """
    if new_state != "ALARM":
        logger.info("Ignoring state %s for %s", new_state, alarm_name)
        return None

    name = alarm_name.lower()
    if name.endswith("-high") or "high" in name:
        return "up"
    if name.endswith("-low") or "low" in name:
        return "down"

    logger.warning("Cannot tell direction from alarm name: %s", alarm_name)
    return None


def _current_size(task_def: dict[str, Any]) -> dict[str, int]:
    cpu = int(task_def.get("cpu") or 0)
    memory = int(task_def.get("memory") or 0)

    # Fall back to the first container if the task-level fields are missing.
    if (cpu == 0 or memory == 0) and task_def.get("containerDefinitions"):
        container = task_def["containerDefinitions"][0]
        cpu = cpu or int(container.get("cpu") or 0)
        memory = memory or int(container.get("memory") or container.get("memoryReservation") or 0)

    return {"cpu": cpu, "memory": memory}


def _find_index(ladder: list[dict[str, int]], size: dict[str, int]) -> int:
    for i, step in enumerate(ladder):
        if step["cpu"] == size["cpu"] and step["memory"] == size["memory"]:
            return i

    # Closest match by memory if the running size is not exactly on the ladder.
    best = 0
    best_delta = abs(ladder[0]["memory"] - size["memory"])
    for i, step in enumerate(ladder):
        delta = abs(step["memory"] - size["memory"])
        if delta < best_delta:
            best = i
            best_delta = delta
    logger.warning(
        "Size %s not on ladder; treating as step %s (%s)",
        size,
        best,
        ladder[best],
    )
    return best


def _next_size(ladder: list[dict[str, int]], current: dict[str, int], direction: str) -> dict[str, int] | None:
    index = _find_index(ladder, current)
    if direction == "up":
        if index >= len(ladder) - 1:
            logger.info("Already at max size %s", ladder[-1])
            return None
        return ladder[index + 1]
    if direction == "down":
        if index <= 0:
            logger.info("Already at min size %s", ladder[0])
            return None
        return ladder[index - 1]
    return None


def _register_resized_task_definition(task_def: dict[str, Any], new_size: dict[str, int]) -> str:
    """Copy the running task definition with a new cpu/memory and register it."""
    containers = []
    for container in task_def["containerDefinitions"]:
        copy = dict(container)
        # Keep container memory in sync so the ECS agent does not fight the task size.
        if "memory" in copy:
            copy["memory"] = new_size["memory"]
        if "memoryReservation" in copy:
            copy["memoryReservation"] = min(copy["memoryReservation"], new_size["memory"])
        containers.append(copy)

    kwargs: dict[str, Any] = {
        "family": task_def["family"],
        "containerDefinitions": containers,
        "requiresCompatibilities": task_def.get("requiresCompatibilities", ["EC2"]),
        "networkMode": task_def.get("networkMode", "bridge"),
        "cpu": str(new_size["cpu"]),
        "memory": str(new_size["memory"]),
    }

    if task_def.get("executionRoleArn"):
        kwargs["executionRoleArn"] = task_def["executionRoleArn"]
    if task_def.get("taskRoleArn"):
        kwargs["taskRoleArn"] = task_def["taskRoleArn"]
    if task_def.get("volumes"):
        kwargs["volumes"] = task_def["volumes"]
    if task_def.get("placementConstraints"):
        kwargs["placementConstraints"] = task_def["placementConstraints"]

    response = ecs.register_task_definition(**kwargs)
    arn = response["taskDefinition"]["taskDefinitionArn"]
    logger.info("Registered %s at cpu=%s memory=%s", arn, new_size["cpu"], new_size["memory"])
    return arn


def scale(direction: str) -> dict[str, Any]:
    ladder = _ladder()

    service = ecs.describe_services(cluster=CLUSTER_NAME, services=[SERVICE_NAME])["services"][0]
    task_def_arn = service["taskDefinition"]
    task_def = ecs.describe_task_definition(taskDefinition=task_def_arn)["taskDefinition"]

    current = _current_size(task_def)
    target = _next_size(ladder, current, direction)
    if target is None:
        return {
            "status": "noop",
            "direction": direction,
            "current": current,
            "reason": "already at ladder edge",
        }

    new_arn = _register_resized_task_definition(task_def, target)
    ecs.update_service(
        cluster=CLUSTER_NAME,
        service=SERVICE_NAME,
        taskDefinition=new_arn,
        forceNewDeployment=True,
    )

    return {
        "status": "scaled",
        "direction": direction,
        "from": current,
        "to": target,
        "taskDefinition": new_arn,
    }


def handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    logger.info("Event: %s", json.dumps(event))

    # Allow a direct invoke for testing: {"direction": "up"}
    if "direction" in event and "Records" not in event:
        result = scale(event["direction"])
        logger.info("Result: %s", result)
        return result

    alarm = _parse_sns_alarm(event)
    alarm_name = alarm.get("AlarmName", "")
    new_state = alarm.get("NewStateValue", "")
    direction = _direction_from_alarm(alarm_name, new_state)
    if direction is None:
        return {"status": "ignored", "alarm": alarm_name, "state": new_state}

    result = scale(direction)
    logger.info("Result: %s", result)
    return result
