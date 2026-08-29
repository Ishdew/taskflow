package com.taskflow.domain;

/**
 * Lifecycle state of a task.
 *
 * <p>Persisted as its name rather than its ordinal, so reordering or inserting constants here can
 * never silently corrupt existing rows. The database mirrors these values in a CHECK constraint.
 */
public enum TaskStatus {
  TODO,
  IN_PROGRESS,
  DONE
}
