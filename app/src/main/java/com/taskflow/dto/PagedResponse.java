package com.taskflow.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;
import org.springframework.data.domain.Page;

/**
 * A stable, explicit envelope for paginated results.
 *
 * <p>Spring's {@code PageImpl} serializes to a JSON structure that Spring Data itself warns is not
 * a stable API contract. Declaring our own envelope keeps the published OpenAPI schema accurate and
 * insulates clients from any future change to Spring's internal representation.
 */
@Schema(description = "A page of results")
public record PagedResponse<T>(
    List<T> content,
    @Schema(description = "Zero-based index of this page", example = "0") int page,
    @Schema(description = "Requested page size", example = "20") int size,
    @Schema(description = "Total matching records across all pages", example = "42")
        long totalElements,
    @Schema(description = "Total number of pages", example = "3") int totalPages,
    @Schema(description = "Whether this is the final page") boolean last) {

  public static <T> PagedResponse<T> from(Page<T> page) {
    return new PagedResponse<>(
        page.getContent(),
        page.getNumber(),
        page.getSize(),
        page.getTotalElements(),
        page.getTotalPages(),
        page.isLast());
  }
}
