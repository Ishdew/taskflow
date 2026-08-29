package com.taskflow.repository;

import com.taskflow.domain.Task;
import com.taskflow.domain.TaskStatus;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface TaskRepository extends JpaRepository<Task, UUID> {

  Page<Task> findByStatus(TaskStatus status, Pageable pageable);
}
