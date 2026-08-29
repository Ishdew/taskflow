package com.taskflow.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.taskflow.domain.Task;
import com.taskflow.domain.TaskPriority;
import com.taskflow.domain.TaskStatus;
import com.taskflow.dto.CreateTaskRequest;
import com.taskflow.dto.PagedResponse;
import com.taskflow.dto.TaskResponse;
import com.taskflow.dto.UpdateTaskRequest;
import com.taskflow.exception.TaskNotFoundException;
import com.taskflow.repository.TaskRepository;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.test.util.ReflectionTestUtils;

@ExtendWith(MockitoExtension.class)
class TaskServiceTest {

  private static final UUID TASK_ID = UUID.fromString("11111111-2222-3333-4444-555555555555");

  @Mock private TaskRepository taskRepository;

  @InjectMocks private TaskService taskService;

  @Test
  void createAppliesDefaultsWhenStatusAndPriorityAreOmitted() {
    when(taskRepository.saveAndFlush(any(Task.class))).thenAnswer(call -> call.getArgument(0));

    taskService.create(new CreateTaskRequest("Write the runbook", null, null, null, null));

    ArgumentCaptor<Task> saved = ArgumentCaptor.forClass(Task.class);
    verify(taskRepository).saveAndFlush(saved.capture());
    assertThat(saved.getValue().getStatus()).isEqualTo(TaskStatus.TODO);
    assertThat(saved.getValue().getPriority()).isEqualTo(TaskPriority.MEDIUM);
  }

  @Test
  void createKeepsExplicitStatusAndPriority() {
    when(taskRepository.saveAndFlush(any(Task.class))).thenAnswer(call -> call.getArgument(0));

    LocalDate due = LocalDate.of(2030, 1, 31);
    TaskResponse response =
        taskService.create(
            new CreateTaskRequest(
                "Ship it", "with care", TaskStatus.IN_PROGRESS, TaskPriority.HIGH, due));

    assertThat(response.status()).isEqualTo(TaskStatus.IN_PROGRESS);
    assertThat(response.priority()).isEqualTo(TaskPriority.HIGH);
    assertThat(response.dueDate()).isEqualTo(due);
    assertThat(response.description()).isEqualTo("with care");
  }

  @Test
  void listWithoutStatusFiltersNothing() {
    Pageable pageable = PageRequest.of(0, 20);
    when(taskRepository.findAll(pageable))
        .thenReturn(new PageImpl<>(List.of(existingTask()), pageable, 1));

    PagedResponse<TaskResponse> page = taskService.list(null, pageable);

    assertThat(page.content()).hasSize(1);
    assertThat(page.totalElements()).isEqualTo(1);
    assertThat(page.last()).isTrue();
    verify(taskRepository, never()).findByStatus(any(), any());
  }

  @Test
  void listWithStatusDelegatesToTheFilteringQuery() {
    Pageable pageable = PageRequest.of(0, 20);
    when(taskRepository.findByStatus(TaskStatus.DONE, pageable))
        .thenReturn(new PageImpl<>(List.of(), pageable, 0));

    PagedResponse<TaskResponse> page = taskService.list(TaskStatus.DONE, pageable);

    assertThat(page.content()).isEmpty();
    verify(taskRepository, never()).findAll(pageable);
  }

  @Test
  void getReturnsTheTask() {
    when(taskRepository.findById(TASK_ID)).thenReturn(Optional.of(existingTask()));

    assertThat(taskService.get(TASK_ID).id()).isEqualTo(TASK_ID);
  }

  @Test
  void getThrowsWhenTheTaskIsAbsent() {
    when(taskRepository.findById(TASK_ID)).thenReturn(Optional.empty());

    assertThatThrownBy(() -> taskService.get(TASK_ID))
        .isInstanceOf(TaskNotFoundException.class)
        .hasMessageContaining(TASK_ID.toString());
  }

  @Test
  void updateReplacesEveryMutableField() {
    Task task = existingTask();
    when(taskRepository.findById(TASK_ID)).thenReturn(Optional.of(task));
    when(taskRepository.saveAndFlush(task)).thenReturn(task);

    LocalDate due = LocalDate.of(2020, 1, 1);
    TaskResponse response =
        taskService.update(
            TASK_ID,
            new UpdateTaskRequest("Renamed", "Rewritten", TaskStatus.DONE, TaskPriority.LOW, due));

    assertThat(response.title()).isEqualTo("Renamed");
    assertThat(response.description()).isEqualTo("Rewritten");
    assertThat(response.status()).isEqualTo(TaskStatus.DONE);
    assertThat(response.priority()).isEqualTo(TaskPriority.LOW);
    // A due date already in the past must be accepted on update, otherwise an overdue task could
    // never be edited, not even to mark it DONE.
    assertThat(response.dueDate()).isEqualTo(due);
  }

  @Test
  void updateThrowsWhenTheTaskIsAbsent() {
    when(taskRepository.findById(TASK_ID)).thenReturn(Optional.empty());

    UpdateTaskRequest request =
        new UpdateTaskRequest("x", null, TaskStatus.TODO, TaskPriority.LOW, null);

    assertThatThrownBy(() -> taskService.update(TASK_ID, request))
        .isInstanceOf(TaskNotFoundException.class);
    verify(taskRepository, never()).saveAndFlush(any());
  }

  @Test
  void deleteRemovesTheTask() {
    Task task = existingTask();
    when(taskRepository.findById(TASK_ID)).thenReturn(Optional.of(task));

    taskService.delete(TASK_ID);

    verify(taskRepository).delete(task);
  }

  @Test
  void deleteThrowsWhenTheTaskIsAbsent() {
    when(taskRepository.findById(TASK_ID)).thenReturn(Optional.empty());

    assertThatThrownBy(() -> taskService.delete(TASK_ID)).isInstanceOf(TaskNotFoundException.class);
    verify(taskRepository, never()).delete(any());
  }

  /**
   * Builds a Task as it would look after a round trip through the database. The id and timestamps
   * are assigned by Hibernate and have no setters, so they are injected reflectively here rather
   * than widening the entity's API purely for tests.
   */
  private static Task existingTask() {
    Task task =
        new Task(
            "Rotate the RDS credential",
            "Quarterly rotation",
            TaskStatus.TODO,
            TaskPriority.HIGH,
            LocalDate.of(2030, 12, 31));
    ReflectionTestUtils.setField(task, "id", TASK_ID);
    ReflectionTestUtils.setField(task, "createdAt", Instant.parse("2026-01-01T00:00:00Z"));
    ReflectionTestUtils.setField(task, "updatedAt", Instant.parse("2026-01-01T00:00:00Z"));
    return task;
  }
}
