
-- ================================================================
-- SisGESC — 02_olap_dw.sql
-- Data Warehouse (OLAP) — Esquema Estrela (Star Schema)
-- ================================================================
-- ARQUITETURA:
--   OLTP : sisgesc_publico_nota  (01_oltp.sql — banco transacional)
--   OLAP  : sisgesc_dw           (este arquivo — camada analítica)
--
-- MODELO DIMENSIONAL (STAR SCHEMA):
--   3 Tabelas Fato:
--     ft_frequencia      — grain: 1 linha por aluno por dia de aula
--     ft_financeiro      — grain: 1 linha por movimento financeiro
--     ft_matricula       — grain: 1 linha por matrícula
--
--   6 Dimensões:
--     dim_tempo           — hierarquia dia > semana > mês > trimestre > ano
--     dim_aluno           — atributos descritivos do aluno (SCD Tipo 2)
--     dim_turma           — turma, turno, faixa etária, ano letivo
--     dim_funcionario     — colaborador responsável
--     dim_programa_social — fonte de custeio financeiro
--     dim_categoria_gastos — classificação das despesas
--
-- ETL (VIEWS de carga):
--   Cada view extrai dados do OLTP e formata para o DW.
--   A carga é feita via sp_carga_dw() — idempotente.
--
-- PRINCIPAL TABELA PARA BI/IA:
--   ft_frequencia — taxa de presença → previsão de evasão escolar
-- ================================================================

USE sisgesc_dw;

-- ================================================================
-- DROP de objetos em ordem inversa de dependência (idempotência)
-- ================================================================

-- Views analíticas
DROP VIEW IF EXISTS vw_bi_taxa_presenca_aluno;
DROP VIEW IF EXISTS vw_bi_painel_financeiro;
DROP VIEW IF EXISTS vw_bi_retencao_turma;
DROP VIEW IF EXISTS vw_bi_gasto_per_capita;

-- Views ETL
DROP VIEW IF EXISTS etl_dim_aluno;
DROP VIEW IF EXISTS etl_dim_turma;
DROP VIEW IF EXISTS etl_dim_funcionario;
DROP VIEW IF EXISTS etl_dim_programa_social;
DROP VIEW IF EXISTS etl_dim_categoria_gastos;
DROP VIEW IF EXISTS etl_ft_frequencia;
DROP VIEW IF EXISTS etl_ft_gastos;
DROP VIEW IF EXISTS etl_ft_pagamentos;
DROP VIEW IF EXISTS etl_ft_matricula;

-- Stored Procedures
DROP PROCEDURE IF EXISTS sp_carga_dw;
DROP PROCEDURE IF EXISTS sp_popular_dim_tempo;

-- Tabelas Fato (dependem das dimensões)
DROP TABLE IF EXISTS ft_frequencia;
DROP TABLE IF EXISTS ft_financeiro;
DROP TABLE IF EXISTS ft_matricula;

-- Tabelas Dimensão (ordem inversa de dependência)
DROP TABLE IF EXISTS dim_aluno;
DROP TABLE IF EXISTS dim_turma;
DROP TABLE IF EXISTS dim_funcionario;
DROP TABLE IF EXISTS dim_programa_social;
DROP TABLE IF EXISTS dim_categoria_gastos;
DROP TABLE IF EXISTS dim_tempo;


-- ================================================================
-- DIMENSÃO TEMPO
-- Granularidade: dia calendário
-- Carregada por sp_popular_dim_tempo (2020-2030 = 3.653 linhas)
-- Hierarquia: dia > semana > mês > trimestre > semestre > ano
-- ================================================================
CREATE TABLE IF NOT EXISTS dim_tempo (
    sk_tempo         INT         NOT NULL,   -- surrogate key: YYYYMMDD ex: 20250317
    data_completa    DATE        NOT NULL,
    dia              INT         NOT NULL,
    mes              INT         NOT NULL,
    nome_mes         VARCHAR(15) NOT NULL,
    trimestre        INT         NOT NULL,
    semestre         INT         NOT NULL,
    ano              INT         NOT NULL,
    semana_ano       INT         NOT NULL,
    dia_semana_num   INT         NOT NULL,   -- 1=Dom … 7=Sáb
    nome_dia_semana  VARCHAR(15) NOT NULL,
    dia_util         BOOLEAN     NOT NULL DEFAULT 1,
    ano_letivo       INT         NOT NULL,   -- alias para joins com tb_turma

    PRIMARY KEY (sk_tempo),
    UNIQUE KEY uq_data_completa (data_completa),
    INDEX idx_dim_tempo_ano   (ano),
    INDEX idx_dim_tempo_mes   (mes),
    INDEX idx_dim_tempo_util  (dia_util)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Dimensão Tempo — hierarquia calendário completa (2020-2030)';


-- ================================================================
-- DIMENSÃO ALUNO (SCD Tipo 2)
-- SCD Tipo 2: mantém histórico quando situacao_aluno muda.
-- Cada mudança gera nova linha com dt_inicio/dt_fim atualizado.
-- fl_atual=1 identifica o registro vigente de cada aluno.
-- ================================================================
CREATE TABLE IF NOT EXISTS dim_aluno (
    sk_aluno       INT         NOT NULL AUTO_INCREMENT,  -- surrogate key
    nk_aluno       INT         NOT NULL,                 -- natural key (pk_aluno do OLTP)
    codigo_aluno   VARCHAR(8)  NOT NULL,                 -- CA000001
    nome_aluno     VARCHAR(120) NOT NULL,
    sexo           VARCHAR(10) NOT NULL,
    raca_cor       VARCHAR(40) NOT NULL,
    faixa_etaria   VARCHAR(20) NOT NULL,                 -- '8-10', '10-12', '12-14'
    situacao_aluno VARCHAR(15) NOT NULL,
    -- SCD Tipo 2
    dt_inicio      DATE        NOT NULL,
    dt_fim         DATE,                                  -- NULL = registro atual
    fl_atual       BOOLEAN     NOT NULL DEFAULT 1,

    PRIMARY KEY (sk_aluno),
    UNIQUE KEY uq_dim_aluno_atual (nk_aluno, fl_atual),
    INDEX idx_nk_aluno  (nk_aluno),
    INDEX idx_fl_atual   (fl_atual)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Dimensão Aluno — SCD Tipo 2 (histórico de situação do aluno)';


-- ================================================================
-- DIMENSÃO TURMA
-- ================================================================
CREATE TABLE IF NOT EXISTS dim_turma (
    sk_turma            INT         NOT NULL AUTO_INCREMENT,
    nk_turma            INT         NOT NULL,
    nome_turma          VARCHAR(50) NOT NULL,
    turno               VARCHAR(10) NOT NULL,
    faixa_etaria        VARCHAR(20) NOT NULL,
    faixa_etaria_inicio INT         NOT NULL,
    faixa_etaria_fim    INT         NOT NULL,
    capacidade_max      INT         NOT NULL,
    ano_letivo          INT         NOT NULL,
    status_turma        VARCHAR(10) NOT NULL,

    PRIMARY KEY (sk_turma),
    UNIQUE KEY uq_dim_turma (nk_turma),
    INDEX idx_nk_turma (nk_turma)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Dimensão Turma — faixa etária e capacidade';


-- ================================================================
-- DIMENSÃO FUNCIONÁRIO
-- ================================================================
CREATE TABLE IF NOT EXISTS dim_funcionario (
    sk_funcionario        INT          NOT NULL AUTO_INCREMENT,
    nk_funcionario        INT          NOT NULL,
    nome_funcionario      VARCHAR(120) NOT NULL,
    cargo                 VARCHAR(60)  NOT NULL,
    tipo_vinculo          VARCHAR(15)  NOT NULL,
    carga_horaria_semanal INT          NOT NULL,
    status_funcionario    VARCHAR(15)  NOT NULL,

    PRIMARY KEY (sk_funcionario),
    UNIQUE KEY uq_dim_funcionario (nk_funcionario),
    INDEX idx_nk_funcionario (nk_funcionario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Dimensão Funcionário — colaboradores da instituição';


-- ================================================================
-- DIMENSÃO PROGRAMA SOCIAL
-- ================================================================
CREATE TABLE IF NOT EXISTS dim_programa_social (
    sk_programa   INT          NOT NULL AUTO_INCREMENT,
    nk_programa   INT          NOT NULL,
    nome_programa VARCHAR(100) NOT NULL,
    descricao     VARCHAR(200),

    PRIMARY KEY (sk_programa),
    UNIQUE KEY uq_dim_programa (nk_programa),
    INDEX idx_nk_programa (nk_programa)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Dimensão Programa Social — fonte de custeio do CCA';


-- ================================================================
-- DIMENSÃO CATEGORIA DE GASTOS
-- ================================================================
CREATE TABLE IF NOT EXISTS dim_categoria_gastos (
    sk_categoria   INT         NOT NULL AUTO_INCREMENT,
    nk_categoria   INT         NOT NULL,
    nome_categoria VARCHAR(60) NOT NULL,
    descricao      VARCHAR(150),

    PRIMARY KEY (sk_categoria),
    UNIQUE KEY uq_dim_categoria (nk_categoria),
    INDEX idx_nk_categoria (nk_categoria)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Dimensão Categoria de Gastos — classificação das despesas';


-- ================================================================
-- TABELA FATO: ft_frequencia
-- Grain: 1 linha por aluno por dia de aula
-- Métricas: presente, ausente
-- PRINCIPAL TABELA PARA BI/IA — feature de taxa de presença
-- ================================================================
CREATE TABLE IF NOT EXISTS ft_frequencia (
    pk_ft_frequencia INT          NOT NULL AUTO_INCREMENT,
    -- Chaves das dimensões
    sk_tempo         INT          NOT NULL,   -- data da aula
    sk_aluno         INT          NOT NULL,
    sk_turma         INT          NOT NULL,
    sk_funcionario   INT          NOT NULL,   -- professor da turma
    -- Chave natural para rastreabilidade ao OLTP
    nk_frequencia    INT          NOT NULL,
    nk_matricula     INT          NOT NULL,
    -- Métricas
    presente         TINYINT      NOT NULL,   -- 1=presente, 0=ausente
    ausente          TINYINT      NOT NULL,   -- derivado: NOT presente
    -- Atributos degenerados (evita JOIN desnecessário)
    motivo_falta     VARCHAR(100),
    mes_referencia   CHAR(7)      NOT NULL,
    -- Rastreabilidade
    dt_carga         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_ft_frequencia),
    UNIQUE KEY uq_ft_freq (nk_frequencia),   -- garante idempotência ETL
    FOREIGN KEY (sk_tempo)       REFERENCES dim_tempo(sk_tempo),
    FOREIGN KEY (sk_aluno)       REFERENCES dim_aluno(sk_aluno),
    FOREIGN KEY (sk_turma)       REFERENCES dim_turma(sk_turma),
    FOREIGN KEY (sk_funcionario) REFERENCES dim_funcionario(sk_funcionario),
    INDEX idx_ft_freq_tempo  (sk_tempo),
    INDEX idx_ft_freq_aluno  (sk_aluno),
    INDEX idx_ft_freq_turma  (sk_turma),
    INDEX idx_ft_freq_mes    (mes_referencia)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Fato Frequência — grain: 1 linha por aluno por dia de aula';


-- ================================================================
-- TABELA FATO: ft_financeiro
-- Grain: 1 linha por movimento financeiro (gasto OU pagamento)
-- Métricas: valor_movimento
-- UNIQUE KEY uq_ft_fin_mov habilita ON DUPLICATE KEY UPDATE na ETL
-- ================================================================
CREATE TABLE IF NOT EXISTS ft_financeiro (
    pk_ft_financeiro INT           NOT NULL AUTO_INCREMENT,
    -- Dimensões
    sk_tempo         INT           NOT NULL,   -- data do movimento
    sk_programa      INT           NOT NULL,
    sk_categoria     INT           NOT NULL,
    sk_funcionario   INT,                      -- nullable: só para pagamentos
    -- Chaves naturais
    nk_repasse       INT           NOT NULL,
    nk_movimento     INT           NOT NULL,   -- pk_gasto ou pk_pagamento
    -- Métricas
    tipo_movimento   VARCHAR(20)   NOT NULL,   -- 'gasto', 'pagamento', 'repasse'
    valor_movimento  DECIMAL(12,2) NOT NULL,
    mes_referencia   CHAR(7)       NOT NULL,
    -- Rastreabilidade
    dt_carga         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_ft_financeiro),
    -- Essencial para idempotência: ON DUPLICATE KEY UPDATE na procedure ETL
    UNIQUE KEY uq_ft_fin_mov (nk_movimento, tipo_movimento),
    FOREIGN KEY (sk_tempo)       REFERENCES dim_tempo(sk_tempo),
    FOREIGN KEY (sk_programa)    REFERENCES dim_programa_social(sk_programa),
    FOREIGN KEY (sk_categoria)   REFERENCES dim_categoria_gastos(sk_categoria),
    FOREIGN KEY (sk_funcionario) REFERENCES dim_funcionario(sk_funcionario),
    INDEX idx_ft_fin_tempo    (sk_tempo),
    INDEX idx_ft_fin_programa (sk_programa),
    INDEX idx_ft_fin_tipo     (tipo_movimento),
    INDEX idx_ft_fin_mes      (mes_referencia)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Fato Financeiro — grain: 1 linha por movimento (gasto/pagamento)';


-- ================================================================
-- TABELA FATO: ft_matricula
-- Grain: 1 linha por matrícula (snapshot de status)
-- Métricas: dias_matriculado, fl_cancelada, fl_concluida, fl_ativa
-- ================================================================
CREATE TABLE IF NOT EXISTS ft_matricula (
    pk_ft_matricula    INT          NOT NULL AUTO_INCREMENT,
    -- Dimensões
    sk_tempo_inicio    INT          NOT NULL,   -- data_matricula
    sk_tempo_fim       INT,                     -- data_encerramento (NULL = ativa)
    sk_aluno           INT          NOT NULL,
    sk_turma           INT          NOT NULL,
    -- Chave natural
    nk_matricula       INT          NOT NULL,
    -- Métricas
    situacao_matricula VARCHAR(10)  NOT NULL,
    dias_matriculado   INT,                     -- calculado no ETL
    fl_cancelada       TINYINT      NOT NULL DEFAULT 0,
    fl_concluida       TINYINT      NOT NULL DEFAULT 0,
    fl_ativa           TINYINT      NOT NULL DEFAULT 0,
    -- Rastreabilidade
    dt_carga           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_ft_matricula),
    UNIQUE KEY uq_ft_mat (nk_matricula),
    FOREIGN KEY (sk_tempo_inicio) REFERENCES dim_tempo(sk_tempo),
    FOREIGN KEY (sk_aluno)        REFERENCES dim_aluno(sk_aluno),
    FOREIGN KEY (sk_turma)        REFERENCES dim_turma(sk_turma),
    INDEX idx_ft_mat_aluno     (sk_aluno),
    INDEX idx_ft_mat_turma     (sk_turma),
    INDEX idx_ft_mat_situacao  (situacao_matricula)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Fato Matrícula — grain: 1 linha por matrícula (snapshot de status)';


-- ================================================================
-- PROCEDURE: sp_popular_dim_tempo
-- Gera registros diários para a dimensão tempo (2020-2030).
-- Usa INSERT IGNORE para ser idempotente.
-- ================================================================
DELIMITER $$

CREATE PROCEDURE sp_popular_dim_tempo(
    p_data_inicio DATE,
    p_data_fim    DATE
)
BEGIN
    DECLARE v_data DATE DEFAULT p_data_inicio;

    WHILE v_data <= p_data_fim DO
        INSERT IGNORE INTO dim_tempo (
            sk_tempo, data_completa, dia, mes, nome_mes,
            trimestre, semestre, ano, semana_ano,
            dia_semana_num, nome_dia_semana, dia_util, ano_letivo
        ) VALUES (
            YEAR(v_data) * 10000 + MONTH(v_data) * 100 + DAY(v_data),
            v_data,
            DAY(v_data),
            MONTH(v_data),
            ELT(MONTH(v_data),
                'Janeiro','Fevereiro','Marco','Abril','Maio','Junho',
                'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'),
            QUARTER(v_data),
            IF(MONTH(v_data) <= 6, 1, 2),
            YEAR(v_data),
            WEEK(v_data, 3),
            DAYOFWEEK(v_data),
            ELT(DAYOFWEEK(v_data),
                'Domingo','Segunda','Terca','Quarta','Quinta','Sexta','Sabado'),
            IF(DAYOFWEEK(v_data) IN (1, 7), 0, 1),
            YEAR(v_data)
        );
        SET v_data = DATE_ADD(v_data, INTERVAL 1 DAY);
    END WHILE;
END$$

DELIMITER ;

-- Executa a carga da dimensão tempo (2020-2030)
CALL sp_popular_dim_tempo('2020-01-01', '2030-12-31');


-- ================================================================
-- VIEWS ETL — Extraem dados do OLTP e formatam para o DW
-- Referência ao schema OLTP: sisgesc_publico_nota
-- ================================================================

-- ETL → dim_aluno
CREATE OR REPLACE VIEW etl_dim_aluno AS
SELECT
    a.pk_aluno                                   AS nk_aluno,
    CONCAT('CA', LPAD(a.pk_aluno, 6, '0'))       AS codigo_aluno,
    a.nome_aluno,
    a.sexo,
    a.raca_cor,
    CASE
        WHEN TIMESTAMPDIFF(YEAR, a.data_nascimento, CURDATE()) BETWEEN  8 AND  9 THEN '8-10'
        WHEN TIMESTAMPDIFF(YEAR, a.data_nascimento, CURDATE()) BETWEEN 10 AND 11 THEN '10-12'
        WHEN TIMESTAMPDIFF(YEAR, a.data_nascimento, CURDATE()) BETWEEN 12 AND 14 THEN '12-14'
        ELSE 'Fora da faixa'
    END                                          AS faixa_etaria,
    a.situacao_aluno,
    CURDATE()                                    AS dt_inicio,
    NULL                                         AS dt_fim,
    1                                            AS fl_atual
FROM sisgesc_publico_nota.tb_aluno a;

-- ETL → dim_turma
CREATE OR REPLACE VIEW etl_dim_turma AS
SELECT
    t.pk_turma                                              AS nk_turma,
    t.nome_turma,
    t.turno,
    CONCAT(t.faixa_etaria_inicio, '-', t.faixa_etaria_fim) AS faixa_etaria,
    t.faixa_etaria_inicio,
    t.faixa_etaria_fim,
    t.capacidade_max,
    t.ano_letivo,
    t.status_turma
FROM sisgesc_publico_nota.tb_turma t;

-- ETL → dim_funcionario
CREATE OR REPLACE VIEW etl_dim_funcionario AS
SELECT
    f.pk_funcionario    AS nk_funcionario,
    f.nome_funcionario,
    c.nome_cargo        AS cargo,
    f.tipo_vinculo,
    f.carga_horaria_semanal,
    f.status_funcionario
FROM sisgesc_publico_nota.tb_funcionario f
JOIN sisgesc_publico_nota.tb_cargo c ON c.pk_cargo = f.fk_cargo;

-- ETL → dim_programa_social
CREATE OR REPLACE VIEW etl_dim_programa_social AS
SELECT
    p.pk_programa AS nk_programa,
    p.nome_programa,
    p.descricao
FROM sisgesc_publico_nota.tb_programa_social p;

-- ETL → dim_categoria_gastos
CREATE OR REPLACE VIEW etl_dim_categoria_gastos AS
SELECT
    cg.pk_categoria AS nk_categoria,
    cg.nome_categoria,
    cg.descricao
FROM sisgesc_publico_nota.tb_categoria_gastos cg;

-- ETL → ft_frequencia
CREATE OR REPLACE VIEW etl_ft_frequencia AS
SELECT
    YEAR(f.data_aula) * 10000 + MONTH(f.data_aula) * 100 + DAY(f.data_aula) AS sk_tempo,
    a.pk_aluno                                               AS nk_aluno_oltp,
    m.fk_turma                                               AS nk_turma_oltp,
    pt.fk_funcionario                                        AS nk_funcionario_oltp,
    f.pk_frequencia                                          AS nk_frequencia,
    f.fk_matricula                                           AS nk_matricula,
    f.presente,
    IF(f.presente = 1, 0, 1)                                AS ausente,
    f.motivo_falta,
    DATE_FORMAT(f.data_aula, '%Y-%m')                        AS mes_referencia
FROM sisgesc_publico_nota.tb_frequencia f
JOIN sisgesc_publico_nota.tb_matricula  m  ON m.pk_matricula = f.fk_matricula
JOIN sisgesc_publico_nota.tb_aluno      a  ON a.pk_aluno     = m.fk_aluno
LEFT JOIN (
    -- Usa o funcionário de menor pk como responsável representativo da turma
    SELECT fk_turma, MIN(fk_funcionario) AS fk_funcionario
    FROM sisgesc_publico_nota.tb_professor_turma
    GROUP BY fk_turma
) pt ON pt.fk_turma = m.fk_turma;

-- ETL → ft_financeiro (gastos operacionais)
CREATE OR REPLACE VIEW etl_ft_gastos AS
SELECT
    YEAR(g.data_gasto) * 10000 + MONTH(g.data_gasto) * 100 + DAY(g.data_gasto) AS sk_tempo,
    r.fk_programa    AS nk_programa_oltp,
    g.fk_categoria   AS nk_categoria_oltp,
    NULL             AS nk_funcionario_oltp,
    g.fk_repasse     AS nk_repasse,
    g.pk_gasto       AS nk_movimento,
    'gasto'          AS tipo_movimento,
    g.valor_gasto    AS valor_movimento,
    r.mes_referencia
FROM sisgesc_publico_nota.tb_gasto g
JOIN sisgesc_publico_nota.tb_repasse r ON r.pk_repasse = g.fk_repasse;

-- ETL → ft_financeiro (pagamentos de funcionários)
CREATE OR REPLACE VIEW etl_ft_pagamentos AS
SELECT
    YEAR(pf.data_pagamento) * 10000 + MONTH(pf.data_pagamento) * 100 + DAY(pf.data_pagamento) AS sk_tempo,
    r.fk_programa    AS nk_programa_oltp,
    (SELECT pk_categoria FROM sisgesc_publico_nota.tb_categoria_gastos
     WHERE nome_categoria = 'Pagamento de Pessoal' LIMIT 1) AS nk_categoria_oltp,
    pf.fk_funcionario AS nk_funcionario_oltp,
    pf.fk_repasse     AS nk_repasse,
    pf.pk_pagamento   AS nk_movimento,
    'pagamento'       AS tipo_movimento,
    pf.valor_pago     AS valor_movimento,
    pf.mes_referencia
FROM sisgesc_publico_nota.tb_pagamento_funcionario pf
JOIN sisgesc_publico_nota.tb_repasse r ON r.pk_repasse = pf.fk_repasse;

-- ETL → ft_matricula
CREATE OR REPLACE VIEW etl_ft_matricula AS
SELECT
    YEAR(m.data_matricula) * 10000 + MONTH(m.data_matricula) * 100 + DAY(m.data_matricula) AS sk_tempo_inicio,
    IF(m.data_encerramento IS NOT NULL,
       YEAR(m.data_encerramento) * 10000 + MONTH(m.data_encerramento) * 100 + DAY(m.data_encerramento),
       NULL)                                     AS sk_tempo_fim,
    m.fk_aluno                                   AS nk_aluno_oltp,
    m.fk_turma                                   AS nk_turma_oltp,
    m.pk_matricula                               AS nk_matricula,
    m.situacao_matricula,
    DATEDIFF(IFNULL(m.data_encerramento, CURDATE()), m.data_matricula) AS dias_matriculado,
    IF(m.situacao_matricula = 'cancelada', 1, 0) AS fl_cancelada,
    IF(m.situacao_matricula = 'concluida', 1, 0) AS fl_concluida,
    IF(m.situacao_matricula = 'ativa',     1, 0) AS fl_ativa
FROM sisgesc_publico_nota.tb_matricula m;


-- ================================================================
-- PROCEDURE DE CARGA ETL
-- sp_carga_dw — Popula o DW a partir do OLTP
-- Executa em ordem: dimensões primeiro, depois fatos.
-- Idempotente: pode ser reexecutada infinitamente sem duplicar dados.
-- ================================================================
DELIMITER $$

CREATE PROCEDURE sp_carga_dw()
BEGIN

    -- -------------------------------------------------------
    -- PASSO 1: Carga das Dimensões
    -- INSERT IGNORE garante idempotência via UNIQUE KEY
    -- -------------------------------------------------------

    -- dim_aluno
    INSERT IGNORE INTO dim_aluno (
        nk_aluno, codigo_aluno, nome_aluno, sexo, raca_cor,
        faixa_etaria, situacao_aluno, dt_inicio, dt_fim, fl_atual
    )
    SELECT nk_aluno, codigo_aluno, nome_aluno, sexo, raca_cor,
           faixa_etaria, situacao_aluno, dt_inicio, dt_fim, fl_atual
    FROM etl_dim_aluno;

    -- dim_turma
    INSERT IGNORE INTO dim_turma (
        nk_turma, nome_turma, turno, faixa_etaria,
        faixa_etaria_inicio, faixa_etaria_fim,
        capacidade_max, ano_letivo, status_turma
    )
    SELECT nk_turma, nome_turma, turno, faixa_etaria,
           faixa_etaria_inicio, faixa_etaria_fim,
           capacidade_max, ano_letivo, status_turma
    FROM etl_dim_turma;

    -- dim_funcionario
    INSERT IGNORE INTO dim_funcionario (
        nk_funcionario, nome_funcionario, cargo,
        tipo_vinculo, carga_horaria_semanal, status_funcionario
    )
    SELECT nk_funcionario, nome_funcionario, cargo,
           tipo_vinculo, carga_horaria_semanal, status_funcionario
    FROM etl_dim_funcionario;

    -- dim_programa_social
    INSERT IGNORE INTO dim_programa_social (nk_programa, nome_programa, descricao)
    SELECT nk_programa, nome_programa, descricao
    FROM etl_dim_programa_social;

    -- dim_categoria_gastos
    INSERT IGNORE INTO dim_categoria_gastos (nk_categoria, nome_categoria, descricao)
    SELECT nk_categoria, nome_categoria, descricao
    FROM etl_dim_categoria_gastos;

    -- -------------------------------------------------------
    -- PASSO 2: Fato Frequência
    -- INSERT IGNORE via UNIQUE KEY uq_ft_freq (nk_frequencia)
    -- -------------------------------------------------------
    INSERT IGNORE INTO ft_frequencia (
        sk_tempo, sk_aluno, sk_turma, sk_funcionario,
        nk_frequencia, nk_matricula, presente, ausente,
        motivo_falta, mes_referencia
    )
    SELECT
        e.sk_tempo,
        da.sk_aluno,
        dt.sk_turma,
        IFNULL(df.sk_funcionario, 1),   -- fallback para o funcionário de pk=1
        e.nk_frequencia,
        e.nk_matricula,
        e.presente,
        e.ausente,
        e.motivo_falta,
        e.mes_referencia
    FROM etl_ft_frequencia e
    JOIN dim_aluno      da ON da.nk_aluno      = e.nk_aluno_oltp      AND da.fl_atual = 1
    JOIN dim_turma      dt ON dt.nk_turma      = e.nk_turma_oltp
    LEFT JOIN dim_funcionario df ON df.nk_funcionario = e.nk_funcionario_oltp;

    -- -------------------------------------------------------
    -- PASSO 3: Fato Financeiro — gastos
    -- ON DUPLICATE KEY UPDATE atualiza valor se houve correção no OLTP
    -- -------------------------------------------------------
    INSERT INTO ft_financeiro (
        sk_tempo, sk_programa, sk_categoria, sk_funcionario,
        nk_repasse, nk_movimento, tipo_movimento, valor_movimento, mes_referencia
    )
    SELECT
        e.sk_tempo,
        dp.sk_programa,
        dc.sk_categoria,
        NULL,
        e.nk_repasse,
        e.nk_movimento,
        e.tipo_movimento,
        e.valor_movimento,
        e.mes_referencia
    FROM etl_ft_gastos e
    JOIN dim_programa_social  dp ON dp.nk_programa  = e.nk_programa_oltp
    JOIN dim_categoria_gastos dc ON dc.nk_categoria = e.nk_categoria_oltp
    ON DUPLICATE KEY UPDATE valor_movimento = VALUES(valor_movimento),
                            dt_carga        = CURRENT_TIMESTAMP;

    -- -------------------------------------------------------
    -- PASSO 4: Fato Financeiro — pagamentos de funcionários
    -- -------------------------------------------------------
    INSERT INTO ft_financeiro (
        sk_tempo, sk_programa, sk_categoria, sk_funcionario,
        nk_repasse, nk_movimento, tipo_movimento, valor_movimento, mes_referencia
    )
    SELECT
        e.sk_tempo,
        dp.sk_programa,
        dc.sk_categoria,
        df.sk_funcionario,
        e.nk_repasse,
        e.nk_movimento,
        e.tipo_movimento,
        e.valor_movimento,
        e.mes_referencia
    FROM etl_ft_pagamentos e
    JOIN dim_programa_social  dp ON dp.nk_programa   = e.nk_programa_oltp
    JOIN dim_categoria_gastos dc ON dc.nk_categoria  = e.nk_categoria_oltp
    JOIN dim_funcionario      df ON df.nk_funcionario = e.nk_funcionario_oltp
    ON DUPLICATE KEY UPDATE valor_movimento = VALUES(valor_movimento),
                            dt_carga        = CURRENT_TIMESTAMP;

    -- -------------------------------------------------------
    -- PASSO 5: Fato Matrícula
    -- INSERT IGNORE via UNIQUE KEY uq_ft_mat (nk_matricula)
    -- -------------------------------------------------------
    INSERT IGNORE INTO ft_matricula (
        sk_tempo_inicio, sk_tempo_fim, sk_aluno, sk_turma,
        nk_matricula, situacao_matricula, dias_matriculado,
        fl_cancelada, fl_concluida, fl_ativa
    )
    SELECT
        e.sk_tempo_inicio,
        e.sk_tempo_fim,
        da.sk_aluno,
        dt.sk_turma,
        e.nk_matricula,
        e.situacao_matricula,
        e.dias_matriculado,
        e.fl_cancelada,
        e.fl_concluida,
        e.fl_ativa
    FROM etl_ft_matricula e
    JOIN dim_aluno da ON da.nk_aluno = e.nk_aluno_oltp AND da.fl_atual = 1
    JOIN dim_turma dt ON dt.nk_turma = e.nk_turma_oltp;

    SELECT 'Carga ETL concluida com sucesso.' AS status;
END$$

DELIMITER ;


-- ================================================================
-- VIEWS ANALÍTICAS — Consultas prontas para BI e IA
-- ================================================================

-- ------------------------------------------------------------------
-- vw_bi_taxa_presenca_aluno
-- Taxa de presença por aluno e mês
-- Feature principal para previsão de evasão (fl_risco_evasao)
-- Critério: taxa < 75% → risco de evasão
-- ------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_bi_taxa_presenca_aluno AS
SELECT
    da.codigo_aluno,
    da.nome_aluno,
    da.faixa_etaria,
    da.situacao_aluno,
    dt.nome_turma,
    dt.turno,
    f.mes_referencia,
    COUNT(*)                                                    AS total_aulas,
    SUM(f.presente)                                             AS presencas,
    SUM(f.ausente)                                              AS ausencias,
    ROUND(SUM(f.presente) * 100.0 / COUNT(*), 1)               AS taxa_presenca_pct,
    -- Feature para IA: aluno em risco se taxa < 75%
    IF(ROUND(SUM(f.presente) * 100.0 / COUNT(*), 1) < 75, 1, 0) AS fl_risco_evasao
FROM ft_frequencia f
JOIN dim_aluno  da ON da.sk_aluno = f.sk_aluno
JOIN dim_turma  dt ON dt.sk_turma = f.sk_turma
JOIN dim_tempo  t  ON t.sk_tempo  = f.sk_tempo
GROUP BY da.codigo_aluno, da.nome_aluno, da.faixa_etaria, da.situacao_aluno,
         dt.nome_turma, dt.turno, f.mes_referencia;

-- ------------------------------------------------------------------
-- vw_bi_painel_financeiro
-- Painel financeiro: gastos vs pagamentos por mês e programa
-- ------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_bi_painel_financeiro AS
SELECT
    f.mes_referencia,
    dp.nome_programa,
    SUM(CASE WHEN f.tipo_movimento = 'gasto'     THEN f.valor_movimento ELSE 0 END) AS total_gastos,
    SUM(CASE WHEN f.tipo_movimento = 'pagamento' THEN f.valor_movimento ELSE 0 END) AS total_pagamentos,
    SUM(f.valor_movimento)                                      AS total_desembolsado
FROM ft_financeiro f
JOIN dim_programa_social dp ON dp.sk_programa = f.sk_programa
GROUP BY f.mes_referencia, dp.nome_programa
ORDER BY f.mes_referencia, dp.nome_programa;

-- ------------------------------------------------------------------
-- vw_bi_retencao_turma
-- Ocupação e retenção por turma e ano letivo
-- ------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_bi_retencao_turma AS
SELECT
    dt.nome_turma,
    dt.turno,
    dt.faixa_etaria,
    dt.ano_letivo,
    COUNT(*)                                                     AS total_matriculas,
    SUM(m.fl_ativa)                                              AS ativas,
    SUM(m.fl_cancelada)                                          AS canceladas,
    SUM(m.fl_concluida)                                          AS concluidas,
    ROUND(AVG(m.dias_matriculado), 0)                            AS media_dias_permanencia,
    ROUND(SUM(m.fl_concluida)  * 100.0 / COUNT(*), 1)           AS taxa_conclusao_pct,
    ROUND(SUM(m.fl_cancelada)  * 100.0 / COUNT(*), 1)           AS taxa_cancelamento_pct
FROM ft_matricula m
JOIN dim_turma dt ON dt.sk_turma = m.sk_turma
GROUP BY dt.nome_turma, dt.turno, dt.faixa_etaria, dt.ano_letivo;

-- ------------------------------------------------------------------
-- vw_bi_gasto_per_capita
-- Gasto per capita por aluno ativo (eficiência financeira)
-- ------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_bi_gasto_per_capita AS
SELECT
    f.mes_referencia,
    SUM(f.valor_movimento)                                       AS total_desembolsado,
    (SELECT COUNT(*) FROM ft_matricula m2 WHERE m2.fl_ativa = 1) AS alunos_ativos,
    ROUND(SUM(f.valor_movimento) /
          NULLIF((SELECT COUNT(*) FROM ft_matricula m2
                  WHERE m2.fl_ativa = 1), 0), 2)                 AS gasto_per_capita
FROM ft_financeiro f
GROUP BY f.mes_referencia;


-- ================================================================
-- CARGA INICIAL DO DW
-- ================================================================
CALL sp_carga_dw();


-- ================================================================
-- VALIDAÇÕES OBRIGATÓRIAS — Contagem de registros por tabela DW
-- ================================================================
SELECT '--- VALIDAÇÕES DW (OLAP) ---' AS status;
SELECT 'dim_tempo'            AS tabela, COUNT(*) AS registros FROM dim_tempo            UNION ALL
SELECT 'dim_aluno',                      COUNT(*)              FROM dim_aluno             UNION ALL
SELECT 'dim_turma',                      COUNT(*)              FROM dim_turma             UNION ALL
SELECT 'dim_funcionario',                COUNT(*)              FROM dim_funcionario       UNION ALL
SELECT 'dim_programa_social',            COUNT(*)              FROM dim_programa_social   UNION ALL
SELECT 'dim_categoria_gastos',           COUNT(*)              FROM dim_categoria_gastos  UNION ALL
SELECT 'ft_frequencia',                  COUNT(*)              FROM ft_frequencia         UNION ALL
SELECT 'ft_financeiro',                  COUNT(*)              FROM ft_financeiro         UNION ALL
SELECT 'ft_matricula',                   COUNT(*)              FROM ft_matricula;

-- ================================================================
-- VALIDAÇÃO DE INTEGRIDADE FINANCEIRA OLTP × OLAP
-- Comprova que os valores chegaram íntegros ao DW.
-- Todos os totais devem bater:
--   OLTP gastos     = R$  1.200,00
--   OLTP pagamentos = R$ 13.700,00
--   OLTP total      = R$ 14.900,00   ← deve ser igual ao OLAP total
-- ================================================================
SELECT '--- VALIDAÇÃO OLTP vs OLAP (devem ser iguais) ---' AS status;
SELECT 'OLTP gastos'     AS origem, SUM(valor_gasto) AS total
FROM sisgesc_publico_nota.tb_gasto

UNION ALL

SELECT 'OLTP pagamentos', SUM(valor_pago)
FROM sisgesc_publico_nota.tb_pagamento_funcionario

UNION ALL

SELECT 'OLTP total',
    (SELECT SUM(valor_gasto) FROM sisgesc_publico_nota.tb_gasto)
    + (SELECT SUM(valor_pago) FROM sisgesc_publico_nota.tb_pagamento_funcionario)

UNION ALL

SELECT 'OLAP gastos',  SUM(valor_movimento)
FROM sisgesc_dw.ft_financeiro WHERE tipo_movimento = 'gasto'

UNION ALL

SELECT 'OLAP pagamentos', SUM(valor_movimento)
FROM sisgesc_dw.ft_financeiro WHERE tipo_movimento = 'pagamento'

UNION ALL

SELECT 'OLAP total', SUM(valor_movimento)
FROM sisgesc_dw.ft_financeiro
WHERE tipo_movimento IN ('gasto','pagamento');

-- Painel de taxa de presença (feature IA)
SELECT '--- PAINEL TAXA DE PRESENÇA (BI/IA) ---' AS status;
SELECT * FROM vw_bi_taxa_presenca_aluno;

-- Painel financeiro
SELECT '--- PAINEL FINANCEIRO ---' AS status;
SELECT * FROM vw_bi_painel_financeiro;

-- Retenção por turma
SELECT '--- RETENÇÃO POR TURMA ---' AS status;
SELECT * FROM vw_bi_retencao_turma;

-- Gasto per capita
SELECT '--- GASTO PER CAPITA ---' AS status;
SELECT * FROM vw_bi_gasto_per_capita;

SELECT 'DW (OLAP) carregado com sucesso.' AS status;
