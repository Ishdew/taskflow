package com.taskflow.dto;

import com.taskflow.domain.TaskPriority;
import com.taskflow.domain.TaskStatus;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

/**
 * Payload for creating a task.
 *
 * <p>{@code status} and {@code priority} are optional; omitting them falls back to {@code TODO} and
 * {@code MEDIUM}. A new task may not be created already overdue, hence {@code @FutureOrPresent}.
 */
@Schema(description = "Fields accepted when creating a task")
public record CreateTaskRequest(
    @Schema(
            example = "Rotate the RDS master credential",
            requiredMode = Schema.RequiredMode.REQUIRED)
        @NotBlank(message = "title must not be blank")
        @Size(max = 200, message = "title must not exceed 200 characters")
        String title,
    @Schema(example = "Quarterly credential rotation, coordinate with the on-call engineer.")
        @Size(max = 2000, message = "description must not exceed 2000 characters")
        String description,
    @Schema(example = "TODO", defaultValue = "TODO") TaskStatus status,
    @Schema(example = "HIGH", defaultValue = "MEDIUM") TaskPriority priority,
    @Schema(example = "2026-12-31") @FutureOrPresent(message = "dueDate must not be in the past")
        LocalDate dueDate) {}
