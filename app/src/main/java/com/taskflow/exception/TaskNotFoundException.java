package com.taskflow.exception;

import java.util.UUID;

/** Raised when a task is addressed by an id that does not exist. Surfaces as HTTP 404. */
public class TaskNotFoundException extends RuntimeException {

  private final UUID taskId;

  public TaskNotFoundException(UUID taskId) {
    super("Task %s does not exist".formatted(taskId));
    this.taskId = taskId;
  }

  public UUID getTaskId() {
    return taskId;
  }
}
