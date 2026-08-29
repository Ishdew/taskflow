package com.taskflow.support;

import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

/**
 * Base class for integration tests, backed by a real PostgreSQL container.
 *
 * <p>Tests run against the same engine and the same Flyway migrations as production. An in-memory
 * database would not exercise the {@code TIMESTAMPTZ} and {@code uuid} column types, would not run
 * the CHECK constraints, and would let a mismatch between the entity and the migration go unnoticed
 * until deployment, which is precisely what {@code ddl-auto=validate} exists to catch.
 *
 * <p>The container is started once in a static initialiser and deliberately never stopped, rather
 * than using {@code @Testcontainers} with {@code @Container}. That annotation pair stops the
 * container when each test class finishes, so every integration test class would pay a fresh
 * database startup. Ryuk removes it when the JVM exits.
 */
public abstract class AbstractPostgresIT {

  protected static final PostgreSQLContainer<?> POSTGRES =
      new PostgreSQLContainer<>(DockerImageName.parse("postgres:16-alpine"))
          .withDatabaseName("taskflow")
          .withUsername("taskflow")
          .withPassword("taskflow_test");

  static {
    POSTGRES.start();
  }

  /**
   * Overrides the whole JDBC URL rather than the DB_HOST/DB_PORT parts that application.yml
   * composes, because the container's mapped port is only known at runtime.
   */
  @DynamicPropertySource
  static void datasourceProperties(DynamicPropertyRegistry registry) {
    registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
    registry.add("spring.datasource.username", POSTGRES::getUsername);
    registry.add("spring.datasource.password", POSTGRES::getPassword);
  }
}
