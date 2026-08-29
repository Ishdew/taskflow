package com.taskflow.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.boot.info.BuildProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Document metadata for the published OpenAPI specification.
 *
 * <p>Without this, springdoc emits its placeholder defaults ("OpenAPI definition", version "v0").
 * The version is read from the generated build-info so the specification always reports the build
 * it was produced from, rather than a number that has to be remembered and updated by hand.
 */
@Configuration
public class OpenApiConfig {

  @Bean
  public OpenAPI taskflowOpenApi(ObjectProvider<BuildProperties> buildProperties) {
    BuildProperties build = buildProperties.getIfAvailable();

    return new OpenAPI()
        .info(
            new Info()
                .title("TaskFlow API")
                .description(
                    """
                    Internal task management service.

                    Errors are returned as RFC 7807 problem documents with the \
                    `application/problem+json` content type. Validation failures carry an \
                    additional `errors` array naming each rejected field.""")
                .version(build != null ? build.getVersion() : "unknown")
                .license(new License().name("Proprietary - GTN Technologies")));
  }
}
