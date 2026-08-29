package com.taskflow.service;

import com.taskflow.domain.Task;
import com.taskflow.domain.TaskPriority;
import com.taskflow.domain.TaskStatus;
import com.taskflow.dto.CreateTaskRequest;
import com.taskflow.dto.PagedResponse;
import com.taskflow.dto.TaskResponse;
import com.taskflow.dto.UpdateTaskRequest;
import com.taskflow.exception.TaskNotFoundException;
import com.taskflow.repository.TaskRepository;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Business operations on tasks. Transaction boundaries live here, not in the controller. */
@Service
@Transactional(readOnly = true)
public class TaskService {

  private static final Logger log = LoggerFactory.getLogger(TaskService.class);

  private static final TaskStatus DEFAULT_STATUS = TaskStatus.TODO;
  private static final TaskPriority DEFAULT_PRIORITY = TaskPriority.MEDIUM;

  private final TaskRepository taskRepository;

  public TaskService(TaskRepository taskRepository) {
    this.taskRepository = taskRepository;
  }

  @Transactional
  public TaskResponse create(CreateTaskRequest request) {
    Task task =
        new Task(
            request.title(),
            request.description(),
            request.status() != null ? request.status() : DEFAULT_STATUS,
            request.priority() != null ? request.priority() : DEFAULT_PRIORITY,
            request.dueDate());

    // saveAndFlush rather than save: @CreationTimestamp is populated by Hibernate as part of the
    // INSERT, and a plain save() only stages that insert in the persistence context. The flush
    // would not happen until commit, which is after this method has already mapped the response,
    // so the caller would receive createdAt and updatedAt as null.
    Task saved = taskRepository.saveAndFlush(task);
    log.info("Task created id={} status={}", saved.getId(), saved.getStatus());
    return TaskResponse.from(saved);
  }

  public PagedResponse<TaskResponse> list(TaskStatus status, Pageable pageable) {
    Page<Task> tasks =
        status == null
            ? taskRepository.findAll(pageable)
            : taskRepository.findByStatus(status, pageable);
    return PagedResponse.from(tasks.map(TaskResponse::from));
  }

  public TaskResponse get(UUID id) {
    return TaskResponse.from(findOrThrow(id));
  }

  @Transactional
  public TaskResponse update(UUID id, UpdateTaskRequest request) {
    Task task = findOrThrow(id);
    task.setTitle(request.title());
    task.setDescription(request.description());
    task.setStatus(request.status());
    task.setPriority(request.priority());
    task.setDueDate(request.dueDate());

    // saveAndFlush, not plain dirty checking: the UPDATE has to hit the database before we map the
    // response, otherwise @UpdateTimestamp has not fired yet and we would return the stale
    // updatedAt from before this edit.
    Task saved = taskRepository.saveAndFlush(task);
    log.info("Task updated id={} status={}", id, saved.getStatus());
    return TaskResponse.from(saved);
  }

  @Transactional
  public void delete(UUID id) {
    taskRepository.delete(findOrThrow(id));
    log.info("Task deleted id={}", id);
  }

  private Task findOrThrow(UUID id) {
    return taskRepository.findById(id).orElseThrow(() -> new TaskNotFoundException(id));
  }
}
