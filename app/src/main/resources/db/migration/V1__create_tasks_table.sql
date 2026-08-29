-- TaskFlow initial schema.
--
-- Flyway owns this schema outright; the application runs with ddl-auto=validate so that any
-- divergence between the JPA entity and these definitions fails at startup rather than being
-- silently "fixed" against a production table.

CREATE TABLE tasks (
    id          UUID          NOT NULL,
    title       VARCHAR(200)  NOT NULL,
    description VARCHAR(2000),
    status      VARCHAR(20)   NOT NULL,
    priority    VARCHAR(20)   NOT NULL,
    due_date    DATE,
    created_at  TIMESTAMPTZ   NOT NULL,
    updated_at  TIMESTAMPTZ   NOT NULL,

    CONSTRAINT pk_tasks PRIMARY KEY (id),

    -- The enum values are duplicated here on purpose. The application is not the only thing that
    -- can write to this database (migrations, a restored snapshot, an operator running psql during
    -- an incident), so the valid set is enforced by the database itself rather than trusted to the
    -- caller. Keep these in sync with TaskStatus and TaskPriority.
    CONSTRAINT ck_tasks_status CHECK (status IN ('TODO', 'IN_PROGRESS', 'DONE')),
    CONSTRAINT ck_tasks_priority CHECK (priority IN ('LOW', 'MEDIUM', 'HIGH')),

    CONSTRAINT ck_tasks_title_not_blank CHECK (length(trim(title)) > 0)
);

-- Supports the status filter on GET /api/v1/tasks.
CREATE INDEX idx_tasks_status ON tasks (status);

-- The default listing is ordered by created_at DESC; this lets that page be served from the index
-- instead of sorting the whole table on every request.
CREATE INDEX idx_tasks_created_at_desc ON tasks (created_at DESC);
