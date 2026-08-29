package com.taskflow.web;

import com.taskflow.domain.TaskStatus;
import com.taskflow.dto.CreateTaskRequest;
import com.taskflow.dto.PagedResponse;
import com.taskflow.dto.TaskResponse;
import com.taskflow.dto.UpdateTaskRequest;
import com.taskflow.service.TaskService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.net.URI;
import java.util.UUID;
import org.springdoc.core.annotations.ParameterObject;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

@RestController
@RequestMapping(path = "/api/v1/tasks", produces = MediaType.APPLICATION_JSON_VALUE)
@Tag(name = "Tasks", description = "Create, retrieve, update and delete tasks")
public class TaskController {

  private final TaskService taskService;

  public TaskController(TaskService taskService) {
    this.taskService = taskService;
  }

  @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
  @Operation(summary = "Create a task")
  @ApiResponse(responseCode = "201", description = "Task created")
  @ApiResponse(
      responseCode = "400",
      description = "Validation failed",
      content = @Content(schema = @Schema(implementation = ProblemDetail.class)))
  public ResponseEntity<TaskResponse> create(@Valid @RequestBody CreateTaskRequest request) {
    TaskResponse created = taskService.create(request);
    URI location =
        ServletUriComponentsBuilder.fromCurrentRequest()
            .path("/{id}")
            .buildAndExpand(created.id())
            .toUri();
    return ResponseEntity.created(location).body(created);
  }

  @GetMapping
  @Operation(summary = "List tasks, newest first, optionally filtered by status")
  @ApiResponse(responseCode = "200", description = "A page of tasks")
  public PagedResponse<TaskResponse> list(
      @Parameter(description = "Return only tasks in this status") @RequestParam(required = false)
          TaskStatus status,
      @ParameterObject
          @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC)
          Pageable pageable) {
    return taskService.list(status, pageable);
  }

  @GetMapping("/{id}")
  @Operation(summary = "Retrieve a single task")
  @ApiResponse(responseCode = "200", description = "The task")
  @ApiResponse(
      responseCode = "404",
      description = "No task with that id",
      content = @Content(schema = @Schema(implementation = ProblemDetail.class)))
  public TaskResponse get(@PathVariable UUID id) {
    return taskService.get(id);
  }

  @PutMapping(path = "/{id}", consumes = MediaType.APPLICATION_JSON_VALUE)
  @Operation(summary = "Replace a task")
  @ApiResponse(responseCode = "200", description = "The updated task")
  @ApiResponse(
      responseCode = "400",
      description = "Validation failed",
      content = @Content(schema = @Schema(implementation = ProblemDetail.class)))
  @ApiResponse(
      responseCode = "404",
      description = "No task with that id",
      content = @Content(schema = @Schema(implementation = ProblemDetail.class)))
  public TaskResponse update(@PathVariable UUID id, @Valid @RequestBody UpdateTaskRequest request) {
    return taskService.update(id, request);
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @Operation(summary = "Delete a task")
  @ApiResponse(responseCode = "204", description = "Task deleted")
  @ApiResponse(
      responseCode = "404",
      description = "No task with that id",
      content = @Content(schema = @Schema(implementation = ProblemDetail.class)))
  public void delete(@PathVariable UUID id) {
    taskService.delete(id);
  }
}
