package com.taskflow.dto;

import com.taskflow.domain.TaskPriority;
import com.taskflow.domain.TaskStatus;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

/**
 * Payload for replacing a task. PUT is a full replacement, so every meaningful field is required.
 *
 * <p>Unlike {@link CreateTaskRequest}, {@code dueDate} is deliberately not constrained to the
 * future: a task that has already slipped past its due date must still be editable, and rejecting
 * its existing date would make it impossible to so much as mark it DONE.
 */
@Schema(description = "Fields accepted when replacing a task")
public record UpdateTaskRequest(
    @Schema(
            example = "Rotate the RDS master credential",
            requiredMode = Schema.RequiredMode.REQUIRED)
        @NotBlank(message = "title must not be blank")
        @Size(max = 200, message = "title must not exceed 200 characters")
        String title,
    @Schema(example = "Quarterly credential rotation, coordinate with the on-call engineer.")
        @Size(max = 2000, message = "description must not exceed 2000 characters")
        String description,
    @Schema(example = "IN_PROGRESS", requiredMode = Schema.RequiredMode.REQUIRED)
        @NotNull(message = "status is required")
        TaskStatus status,
    @Schema(example = "HIGH", requiredMode = Schema.RequiredMode.REQUIRED)
        @NotNull(message = "priority is required")
        TaskPriority priority,
    @Schema(example = "2026-12-31") LocalDate dueDate) {}
