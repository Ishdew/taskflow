package com.taskflow.domain;

/** Relative importance of a task. Persisted by name, mirrored by a database CHECK constraint. */
public enum TaskPriority {
  LOW,
  MEDIUM,
  HIGH
}
