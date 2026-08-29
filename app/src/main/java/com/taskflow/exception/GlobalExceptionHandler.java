package com.taskflow.exception;

import jakarta.servlet.http.HttpServletRequest;
import java.net.URI;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

/**
 * Centralised error handling. Every failure leaves the API as an RFC 7807 {@code
 * application/problem+json} document, so clients get one predictable error shape.
 *
 * <p>This extends {@link ResponseEntityExceptionHandler} rather than declaring a bare advice class.
 * That base class already maps the standard Spring MVC failures (405 for a wrong method, 415 for an
 * unsupported media type, 400 for malformed JSON) to sensible statuses. Without it, the catch-all
 * {@code Exception} handler below would swallow all of them and report 500.
 */
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

  private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);
  private static final String PROBLEM_TYPE_BASE = "https://taskflow.internal/problems/";

  @Override
  protected ResponseEntity<Object> handleMethodArgumentNotValid(
      MethodArgumentNotValidException ex,
      HttpHeaders headers,
      HttpStatusCode status,
      WebRequest request) {

    List<ValidationError> errors =
        ex.getBindingResult().getFieldErrors().stream()
            .map(fe -> new ValidationError(fe.getField(), fe.getDefaultMessage()))
            .sorted(Comparator.comparing(ValidationError::field))
            .toList();

    ProblemDetail problem =
        problem(
            HttpStatus.BAD_REQUEST,
            "validation-failed",
            "Validation failed",
            "The request body has %d invalid field(s)".formatted(errors.size()));
    problem.setProperty("errors", errors);

    return ResponseEntity.badRequest().body(problem);
  }

  @ExceptionHandler(TaskNotFoundException.class)
  public ProblemDetail handleTaskNotFound(TaskNotFoundException ex, HttpServletRequest request) {
    ProblemDetail problem =
        problem(HttpStatus.NOT_FOUND, "task-not-found", "Task not found", ex.getMessage());
    problem.setProperty("taskId", ex.getTaskId());
    return withInstance(problem, request);
  }

  /**
   * Covers a malformed UUID in the path and an unrecognised enum constant in a query parameter,
   * both of which are client mistakes and must not surface as 500s.
   */
  @ExceptionHandler(MethodArgumentTypeMismatchException.class)
  public ProblemDetail handleTypeMismatch(
      MethodArgumentTypeMismatchException ex, HttpServletRequest request) {

    Class<?> required = ex.getRequiredType();
    String expected =
        required != null && required.isEnum()
            ? "one of " + List.of(required.getEnumConstants())
            : "a valid " + (required != null ? required.getSimpleName() : "value");

    ProblemDetail problem =
        problem(
            HttpStatus.BAD_REQUEST,
            "invalid-parameter",
            "Invalid parameter",
            "Parameter '%s' must be %s but was '%s'"
                .formatted(ex.getName(), expected, ex.getValue()));
    problem.setProperty("parameter", ex.getName());
    return withInstance(problem, request);
  }

  /**
   * Last line of defence. The real cause is logged with a stack trace but never returned, so an
   * internal failure cannot leak schema names, SQL, or file paths to a caller.
   */
  @ExceptionHandler(Exception.class)
  public ProblemDetail handleUnexpected(Exception ex, HttpServletRequest request) {
    log.error("Unhandled exception on {} {}", request.getMethod(), request.getRequestURI(), ex);
    ProblemDetail problem =
        problem(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "internal-error",
            "Internal server error",
            "The request could not be completed. Contact support with the timestamp if it persists.");
    return withInstance(problem, request);
  }

  private ProblemDetail problem(HttpStatus status, String type, String title, String detail) {
    ProblemDetail problem = ProblemDetail.forStatusAndDetail(status, detail);
    problem.setType(URI.create(PROBLEM_TYPE_BASE + type));
    problem.setTitle(title);
    problem.setProperty("timestamp", Instant.now());
    return problem;
  }

  private ProblemDetail withInstance(ProblemDetail problem, HttpServletRequest request) {
    problem.setInstance(URI.create(request.getRequestURI()));
    return problem;
  }

  /** One rejected field, as reported inside the {@code errors} array of a 400 response. */
  public record ValidationError(String field, String message) {}
}
