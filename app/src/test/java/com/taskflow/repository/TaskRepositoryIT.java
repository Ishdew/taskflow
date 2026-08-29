package com.taskflow.repository;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.taskflow.domain.Task;
import com.taskflow.domain.TaskPriority;
import com.taskflow.domain.TaskStatus;
import com.taskflow.support.AbstractPostgresIT;
import java.time.LocalDate;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class TaskRepositoryIT extends AbstractPostgresIT {

  @Autowired private TaskRepository taskRepository;

  @Test
  void savingPopulatesTheGeneratedIdAndTimestamps() {
    Task saved = taskRepository.saveAndFlush(task("Provision the VPC", TaskStatus.TODO));

    assertThat(saved.getId()).isNotNull();
    assertThat(saved.getCreatedAt()).isNotNull();
    assertThat(saved.getUpdatedAt()).isNotNull();
  }

  @Test
  void findByStatusReturnsOnlyMatchingTasks() {
    taskRepository.saveAndFlush(task("Provision the VPC", TaskStatus.TODO));
    taskRepository.saveAndFlush(task("Write the runbook", TaskStatus.DONE));
    taskRepository.saveAndFlush(task("Configure the hosts", TaskStatus.DONE));

    Page<Task> done = taskRepository.findByStatus(TaskStatus.DONE, PageRequest.of(0, 10));

    assertThat(done.getTotalElements()).isEqualTo(2);
    assertThat(done.getContent()).allMatch(t -> t.getStatus() == TaskStatus.DONE);
  }

  @Test
  void roundTripsEveryColumnThroughPostgres() {
    Task saved = taskRepository.saveAndFlush(task("Round trip", TaskStatus.IN_PROGRESS));

    Task found = taskRepository.findById(saved.getId()).orElseThrow();

    assertThat(found.getTitle()).isEqualTo("Round trip");
    assertThat(found.getStatus()).isEqualTo(TaskStatus.IN_PROGRESS);
    assertThat(found.getPriority()).isEqualTo(TaskPriority.HIGH);
    assertThat(found.getDueDate()).isEqualTo(LocalDate.of(2030, 12, 31));
  }

  /**
   * The application rejects a blank title with Bean Validation long before this point. This asserts
   * the second line of defence: the CHECK constraint in the migration, which also protects the
   * table from a restored snapshot or an operator running psql during an incident.
   */
  @Test
  void theDatabaseItselfRejectsABlankTitle() {
    Task blank = task("   ", TaskStatus.TODO);

    assertThatThrownBy(() -> taskRepository.saveAndFlush(blank))
        .hasMessageContaining("ck_tasks_title_not_blank");
  }

  private static Task task(String title, TaskStatus status) {
    return new Task(title, "description", status, TaskPriority.HIGH, LocalDate.of(2030, 12, 31));
  }
}
