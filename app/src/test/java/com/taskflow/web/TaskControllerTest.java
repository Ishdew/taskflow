package com.taskflow.web;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.taskflow.domain.TaskPriority;
import com.taskflow.domain.TaskStatus;
import com.taskflow.dto.CreateTaskRequest;
import com.taskflow.dto.PagedResponse;
import com.taskflow.dto.TaskResponse;
import com.taskflow.dto.UpdateTaskRequest;
import com.taskflow.exception.TaskNotFoundException;
import com.taskflow.service.TaskService;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(TaskController.class)
class TaskControllerTest {

  private static final UUID TASK_ID = UUID.fromString("11111111-2222-3333-4444-555555555555");
  private static final String BASE = "/api/v1/tasks";

  @Autowired private MockMvc mockMvc;
  @Autowired private ObjectMapper objectMapper;

  @MockitoBean private TaskService taskService;

  @Test
  void createReturns201WithLocationHeader() throws Exception {
    when(taskService.create(any(CreateTaskRequest.class))).thenReturn(sampleResponse());

    mockMvc
        .perform(
            post(BASE)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    json(
                        new CreateTaskRequest(
                            "Rotate the RDS credential",
                            "Quarterly rotation",
                            null,
                            TaskPriority.HIGH,
                            LocalDate.of(2030, 12, 31)))))
        .andExpect(status().isCreated())
        .andExpect(
            header().string("Location", org.hamcrest.Matchers.endsWith(BASE + "/" + TASK_ID)))
        .andExpect(jsonPath("$.id").value(TASK_ID.toString()))
        .andExpect(jsonPath("$.status").value("TODO"));
  }

  @Test
  void createRejectsABlankTitleWithProblemDetail() throws Exception {
    String body =
        """
        {"title":"   ","description":"x"}
        """;

    mockMvc
        .perform(post(BASE).contentType(MediaType.APPLICATION_JSON).content(body))
        .andExpect(status().isBadRequest())
        .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
        .andExpect(jsonPath("$.title").value("Validation failed"))
        .andExpect(jsonPath("$.errors[0].field").value("title"));
  }

  @Test
  void createRejectsADueDateInThePast() throws Exception {
    String body =
        """
        {"title":"Backdated","dueDate":"2020-01-01"}
        """;

    mockMvc
        .perform(post(BASE).contentType(MediaType.APPLICATION_JSON).content(body))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.errors[0].field").value("dueDate"));
  }

  @Test
  void getReturnsTheTask() throws Exception {
    when(taskService.get(TASK_ID)).thenReturn(sampleResponse());

    mockMvc
        .perform(get(BASE + "/" + TASK_ID))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.title").value("Rotate the RDS credential"));
  }

  @Test
  void getReturns404AsProblemDetailWhenAbsent() throws Exception {
    when(taskService.get(TASK_ID)).thenThrow(new TaskNotFoundException(TASK_ID));

    mockMvc
        .perform(get(BASE + "/" + TASK_ID))
        .andExpect(status().isNotFound())
        .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
        .andExpect(jsonPath("$.title").value("Task not found"))
        .andExpect(jsonPath("$.taskId").value(TASK_ID.toString()));
  }

  @Test
  void malformedUuidInThePathIsARejectedRequestNotAServerError() throws Exception {
    mockMvc
        .perform(get(BASE + "/not-a-uuid"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.title").value("Invalid parameter"))
        .andExpect(jsonPath("$.parameter").value("id"));
  }

  @Test
  void unknownStatusValueIsRejectedAndListsTheAllowedValues() throws Exception {
    mockMvc
        .perform(get(BASE).param("status", "BOGUS"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.detail").value(org.hamcrest.Matchers.containsString("IN_PROGRESS")));
  }

  @Test
  void listReturnsAPagedEnvelope() throws Exception {
    when(taskService.list(eq(null), any()))
        .thenReturn(new PagedResponse<>(List.of(sampleResponse()), 0, 20, 1, 1, true));

    mockMvc
        .perform(get(BASE))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.totalElements").value(1))
        .andExpect(jsonPath("$.last").value(true))
        .andExpect(jsonPath("$.content[0].id").value(TASK_ID.toString()));
  }

  @Test
  void updateReturnsTheUpdatedTask() throws Exception {
    when(taskService.update(eq(TASK_ID), any(UpdateTaskRequest.class)))
        .thenReturn(sampleResponse());

    mockMvc
        .perform(
            put(BASE + "/" + TASK_ID)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    json(
                        new UpdateTaskRequest(
                            "Renamed", null, TaskStatus.DONE, TaskPriority.LOW, null))))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.id").value(TASK_ID.toString()));
  }

  @Test
  void updateRequiresStatusAndPriority() throws Exception {
    String body =
        """
        {"title":"Only a title"}
        """;

    mockMvc
        .perform(put(BASE + "/" + TASK_ID).contentType(MediaType.APPLICATION_JSON).content(body))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.detail").value("The request body has 2 invalid field(s)"));
  }

  @Test
  void deleteReturns204() throws Exception {
    mockMvc.perform(delete(BASE + "/" + TASK_ID)).andExpect(status().isNoContent());

    verify(taskService).delete(TASK_ID);
  }

  @Test
  void unsupportedMethodIs405NotAServerError() throws Exception {
    mockMvc.perform(patch(BASE)).andExpect(status().isMethodNotAllowed());
  }

  @Test
  void unsupportedContentTypeIs415NotAServerError() throws Exception {
    mockMvc
        .perform(post(BASE).contentType(MediaType.TEXT_PLAIN).content("nope"))
        .andExpect(status().isUnsupportedMediaType());
  }

  @Test
  void anUnexpectedFailureIs500AndLeaksNothing() throws Exception {
    doThrow(new IllegalStateException("connection pool exhausted at jdbc:postgresql://internal-db"))
        .when(taskService)
        .delete(TASK_ID);

    mockMvc
        .perform(delete(BASE + "/" + TASK_ID))
        .andExpect(status().isInternalServerError())
        .andExpect(jsonPath("$.title").value("Internal server error"))
        .andExpect(jsonPath("$.detail").value(org.hamcrest.Matchers.not(containsInternalDetail())))
        .andExpect(jsonPath("$.stackTrace").doesNotExist());
  }

  private static org.hamcrest.Matcher<String> containsInternalDetail() {
    return org.hamcrest.Matchers.containsString("jdbc:postgresql");
  }

  private String json(Object value) throws Exception {
    return objectMapper.writeValueAsString(value);
  }

  private static TaskResponse sampleResponse() {
    return new TaskResponse(
        TASK_ID,
        "Rotate the RDS credential",
        "Quarterly rotation",
        TaskStatus.TODO,
        TaskPriority.HIGH,
        LocalDate.of(2030, 12, 31),
        Instant.parse("2026-01-01T00:00:00Z"),
        Instant.parse("2026-01-01T00:00:00Z"));
  }
}
