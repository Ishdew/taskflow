package com.taskflow;

import static org.assertj.core.api.Assertions.assertThat;

import com.taskflow.domain.TaskPriority;
import com.taskflow.domain.TaskStatus;
import com.taskflow.dto.CreateTaskRequest;
import com.taskflow.dto.TaskResponse;
import com.taskflow.dto.UpdateTaskRequest;
import com.taskflow.repository.TaskRepository;
import com.taskflow.support.AbstractPostgresIT;
import java.time.LocalDate;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

/**
 * End-to-end coverage of the whole stack: HTTP in, Flyway-managed PostgreSQL out. This is what
 * proves the entity, the migration and {@code ddl-auto=validate} agree, since a mismatch prevents
 * the context from starting at all.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class TaskApiIT extends AbstractPostgresIT {

  private static final String BASE = "/api/v1/tasks";

  @Autowired private TestRestTemplate restTemplate;
  @Autowired private TaskRepository taskRepository;

  @BeforeEach
  void clearTasks() {
    taskRepository.deleteAll();
  }

  @Test
  void healthEndpointIsServedAtTheRootPathTheLoadBalancerUses() {
    ResponseEntity<Map<String, Object>> response =
        restTemplate.exchange(
            "/health",
            HttpMethod.GET,
            null,
            new org.springframework.core.ParameterizedTypeReference<>() {});

    assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    assertThat(response.getBody()).containsEntry("status", "UP");
  }

  @Test
  void livenessAndReadinessProbesAreAvailableSeparately() {
    assertThat(restTemplate.getForEntity("/health/liveness", String.class).getStatusCode())
        .isEqualTo(HttpStatus.OK);
    assertThat(restTemplate.getForEntity("/health/readiness", String.class).getStatusCode())
        .isEqualTo(HttpStatus.OK);
  }

  @Test
  void fullCrudLifecycle() {
    ResponseEntity<TaskResponse> created =
        restTemplate.postForEntity(
            BASE,
            new CreateTaskRequest(
                "Provision the VPC",
                "Two AZs, one NAT gateway",
                null,
                TaskPriority.HIGH,
                LocalDate.of(2030, 12, 31)),
            TaskResponse.class);

    assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    assertThat(created.getHeaders().getLocation()).isNotNull();
    TaskResponse body = created.getBody();
    assertThat(body).isNotNull();
    assertThat(body.status()).isEqualTo(TaskStatus.TODO);
    // Populated by Hibernate during the INSERT, which only happens because the service flushes
    // before mapping the response.
    assertThat(body.createdAt()).isNotNull();
    assertThat(body.updatedAt()).isNotNull();

    String taskUrl = BASE + "/" + body.id();

    assertThat(restTemplate.getForObject(taskUrl, TaskResponse.class).title())
        .isEqualTo("Provision the VPC");

    ResponseEntity<TaskResponse> updated =
        restTemplate.exchange(
            taskUrl,
            HttpMethod.PUT,
            new HttpEntity<>(
                new UpdateTaskRequest(
                    "Provision the VPC",
                    "Done",
                    TaskStatus.DONE,
                    TaskPriority.LOW,
                    LocalDate.of(2020, 1, 1))),
            TaskResponse.class);

    assertThat(updated.getStatusCode()).isEqualTo(HttpStatus.OK);
    assertThat(updated.getBody()).isNotNull();
    assertThat(updated.getBody().status()).isEqualTo(TaskStatus.DONE);
    assertThat(updated.getBody().updatedAt()).isAfter(body.updatedAt());

    assertThat(restTemplate.exchange(taskUrl, HttpMethod.DELETE, null, Void.class).getStatusCode())
        .isEqualTo(HttpStatus.NO_CONTENT);
    assertThat(restTemplate.getForEntity(taskUrl, String.class).getStatusCode())
        .isEqualTo(HttpStatus.NOT_FOUND);
  }

  @Test
  void listIsPagedAndFilterableByStatus() {
    restTemplate.postForEntity(
        BASE, new CreateTaskRequest("One", null, TaskStatus.TODO, null, null), TaskResponse.class);
    restTemplate.postForEntity(
        BASE, new CreateTaskRequest("Two", null, TaskStatus.DONE, null, null), TaskResponse.class);

    ResponseEntity<String> all = restTemplate.getForEntity(BASE, String.class);
    assertThat(all.getStatusCode()).isEqualTo(HttpStatus.OK);
    assertThat(all.getBody()).contains("\"totalElements\":2");

    ResponseEntity<String> done = restTemplate.getForEntity(BASE + "?status=DONE", String.class);
    assertThat(done.getBody()).contains("\"totalElements\":1").contains("Two");
  }

  @Test
  void validationFailureIsReturnedAsAProblemDocument() {
    HttpHeaders headers = new HttpHeaders();
    headers.setContentType(MediaType.APPLICATION_JSON);

    ResponseEntity<String> response =
        restTemplate.exchange(
            BASE, HttpMethod.POST, new HttpEntity<>("{\"title\":\"\"}", headers), String.class);

    assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    assertThat(response.getBody()).contains("validation-failed").contains("title");
  }
}
