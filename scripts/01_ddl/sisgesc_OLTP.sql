-- ================================================================
-- SisGESC — 01_oltp_ddl.sql
-- Sistema de Gestao Educacional e Social
-- CCA Bom Jesus do Cangaiba
-- DDL: Estrutura Completa do Banco OLTP
-- ================================================================
-- REGRAS DE NEGOCIO:
--   RN01 Aluno deve ter entre 8 e 14 anos (calculado via data_nascimento)
--   RN02 Um aluno so pode ter UMA matricula ativa por vez
--   RN03 Limite total de 200 pessoas (alunos ativos + funcionarios ativos)
--   RN04 Capacidade por turma: Turma1=50, Turma2=60, Turma3=60
--   RN05 Lista de espera max 40; insercao direta bloqueada com fila ativa;
--        prioridade LIFO; turma atribuida pela idade atual do aluno
--   RN06 Aluno com 14 anos completos e encerrado automaticamente
--   RN07 Professor pode atuar em multiplas turmas (N:N)
--   RN08 Pagamento de funcionario vinculado ao repasse do programa social
--   RN09 Idade do aluno deve ser compativel com a faixa etaria da turma
--   RN10 CPF validado com algoritmo de digito verificador
--
-- CAMPOS PARA BI/IA (PREVISAO DE EVASAO):
--   tb_frequencia.presente          taxa de presenca por aluno/turma
--   tb_frequencia.fk_repasse        vinculo direto Academico-Financeiro
--   tb_alerta.tipo_alerta           sinalizacoes de risco de evasao
--   tb_alerta.nivel_risco           grau de urgencia
--   tb_aluno.situacao_aluno         status atual do aluno
--   tb_matricula.situacao_matricula historico de cancelamentos
--   tb_aluno.data_nascimento        calculo de faixa etaria dinamica
--   tb_lista_espera.data_solicitacao tempo de espera na fila
--
-- NOTA DE NOMENCLATURA:
--   Tabelas no singular (tb_aluno, tb_turma) — cada tabela representa
--   o modelo de UMA entidade. Padrao snake_case em todo o projeto.
-- ================================================================

USE sisgesc_publico_nota;

-- Variavel de controle para bypass do trigger de lista de espera
SET @from_waitlist = 0;

-- ================================================================
-- DROP DE OBJETOS DEPENDENTES (ordem inversa de dependencia)
-- Garante reexecucao limpa sem erros de objeto ja existente
-- ================================================================

-- Events
DROP EVENT IF EXISTS evt_encerrar_alunos_14_anos;

-- Procedures
DROP PROCEDURE IF EXISTS sp_encerrar_alunos_14_anos;

-- Triggers — Matricula
DROP TRIGGER IF EXISTS trg_bloquear_insercao_com_fila;
DROP TRIGGER IF EXISTS trg_chamar_lista_espera;
DROP TRIGGER IF EXISTS trg_limite_lista_espera;
DROP TRIGGER IF EXISTS trg_limite_instituicao;
DROP TRIGGER IF EXISTS trg_capacidade_turma_insert;
DROP TRIGGER IF EXISTS trg_validar_turma_por_idade_insert;
DROP TRIGGER IF EXISTS trg_matricula_unica_insert;

-- Triggers — Idade
DROP TRIGGER IF EXISTS trg_validar_idade_aluno_update;
DROP TRIGGER IF EXISTS trg_validar_idade_aluno_insert;

-- Triggers — Vinculo
DROP TRIGGER IF EXISTS trg_vinculo_mesmo_aluno;

-- Triggers — Contatos
DROP TRIGGER IF EXISTS trg_contato_funcionario_insert;
DROP TRIGGER IF EXISTS trg_contato_responsavel_update;
DROP TRIGGER IF EXISTS trg_contato_responsavel_insert;

-- Triggers — CPF
DROP TRIGGER IF EXISTS trg_cpf_funcionario_update;
DROP TRIGGER IF EXISTS trg_cpf_funcionario_insert;
DROP TRIGGER IF EXISTS trg_cpf_responsavel_update;
DROP TRIGGER IF EXISTS trg_cpf_responsavel_insert;
DROP TRIGGER IF EXISTS trg_cpf_aluno_update;
DROP TRIGGER IF EXISTS trg_cpf_aluno_insert;

-- Views
DROP VIEW IF EXISTS vw_total_instituicao;
DROP VIEW IF EXISTS vw_ocupacao_turmas;
DROP VIEW IF EXISTS vw_saldo_repasse;
DROP VIEW IF EXISTS vw_aluno;

-- Functions
DROP FUNCTION IF EXISTS fn_validar_telefone;
DROP FUNCTION IF EXISTS fn_validar_email;
DROP FUNCTION IF EXISTS fn_validar_cpf;

-- ================================================================
-- FUNCOES DE VALIDACAO
-- ================================================================

DELIMITER $$

-- ----------------------------------------------------------------
-- RN10: Validacao de CPF com calculo de digito verificador
-- ----------------------------------------------------------------
CREATE FUNCTION fn_validar_cpf(p_cpf CHAR(11))
RETURNS TINYINT
DETERMINISTIC
BEGIN
    DECLARE v_soma  INT DEFAULT 0;
    DECLARE v_resto INT;
    DECLARE v_i     INT DEFAULT 1;
    DECLARE v_dig1  INT;
    DECLARE v_dig2  INT;

    -- Rejeita formato invalido
    IF LENGTH(p_cpf) <> 11 OR p_cpf REGEXP '[^0-9]' THEN RETURN 0; END IF;

    -- Rejeita sequencias invalidas conhecidas
    IF p_cpf IN (
        '00000000000','11111111111','22222222222','33333333333',
        '44444444444','55555555555','66666666666','77777777777',
        '88888888888','99999999999','12345678909'
    ) THEN RETURN 0; END IF;

    -- Calcula 1o digito verificador
    SET v_soma = 0; SET v_i = 1;
    WHILE v_i <= 9 DO
        SET v_soma = v_soma + CAST(SUBSTRING(p_cpf,v_i,1) AS UNSIGNED) * (11 - v_i);
        SET v_i = v_i + 1;
    END WHILE;
    SET v_resto = v_soma % 11;
    SET v_dig1  = IF(v_resto < 2, 0, 11 - v_resto);

    -- Calcula 2o digito verificador
    SET v_soma = 0; SET v_i = 1;
    WHILE v_i <= 10 DO
        SET v_soma = v_soma + CAST(SUBSTRING(p_cpf,v_i,1) AS UNSIGNED) * (12 - v_i);
        SET v_i = v_i + 1;
    END WHILE;
    SET v_resto = v_soma % 11;
    SET v_dig2  = IF(v_resto < 2, 0, 11 - v_resto);

    IF v_dig1 = CAST(SUBSTRING(p_cpf,10,1) AS UNSIGNED)
       AND v_dig2 = CAST(SUBSTRING(p_cpf,11,1) AS UNSIGNED)
    THEN RETURN 1; ELSE RETURN 0; END IF;
END$$

-- ----------------------------------------------------------------
-- Validacao de e-mail: formato basico usuario@dominio.tld
-- ----------------------------------------------------------------
CREATE FUNCTION fn_validar_email(p_email VARCHAR(120))
RETURNS TINYINT
DETERMINISTIC
BEGIN
    IF p_email REGEXP '^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$'
    THEN RETURN 1; ELSE RETURN 0; END IF;
END$$

-- ----------------------------------------------------------------
-- Validacao de telefone brasileiro: (XX) XXXX-XXXX ou (XX) XXXXX-XXXX
-- ----------------------------------------------------------------
CREATE FUNCTION fn_validar_telefone(p_tel VARCHAR(20))
RETURNS TINYINT
DETERMINISTIC
BEGIN
    IF p_tel REGEXP '^\\([0-9]{2}\\) [0-9]{4,5}-[0-9]{4}$'
    THEN RETURN 1; ELSE RETURN 0; END IF;
END$$

DELIMITER ;


-- ================================================================
-- TABELAS BASE (sem dependencias de FK)
-- ================================================================

-- ----------------------------------------------------------------
-- Alunos atendidos pela instituicao (8 a 14 anos) — RN01
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_aluno (
    pk_aluno        INT          NOT NULL AUTO_INCREMENT,
    nome_aluno      VARCHAR(60)  NOT NULL,
    nis_aluno       CHAR(11)     NOT NULL,
    cpf_aluno       CHAR(11)     NOT NULL,
    sexo            ENUM('Masculino','Feminino') NOT NULL,
    data_nascimento DATE         NOT NULL,
    raca_cor        ENUM('Branca','Preta','Parda','Amarela','Indigena','Nao declarada')
                                 NOT NULL DEFAULT 'Nao declarada',
    situacao_aluno  ENUM('ativo','inativo','transferido','concluido')
                                 NOT NULL DEFAULT 'ativo',
    data_criacao    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_aluno),
    UNIQUE KEY uq_nis_aluno (nis_aluno),
    UNIQUE KEY uq_cpf_aluno (cpf_aluno),
    CONSTRAINT chk_cpf_aluno CHECK (cpf_aluno REGEXP '^[0-9]{11}$'),
    CONSTRAINT chk_nis_aluno CHECK (nis_aluno  REGEXP '^[0-9]{11}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Responsaveis legais dos alunos
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_responsavel (
    pk_responsavel   INT          NOT NULL AUTO_INCREMENT,
    cpf_responsavel  CHAR(11)     NOT NULL,
    nome_responsavel VARCHAR(120) NOT NULL,
    data_criacao     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_responsavel),
    UNIQUE KEY uq_cpf_responsavel (cpf_responsavel),
    CONSTRAINT chk_cpf_responsavel CHECK (cpf_responsavel REGEXP '^[0-9]{11}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Cargos da instituicao
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_cargo (
    pk_cargo             INT          NOT NULL AUTO_INCREMENT,
    nome_cargo           VARCHAR(30)  NOT NULL,
    descricao_cargo      VARCHAR(200),
    carga_horaria_padrao INT          NOT NULL,
    data_criacao         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_cargo),
    UNIQUE KEY uq_nome_cargo (nome_cargo),
    CONSTRAINT chk_carga_horaria_padrao CHECK (carga_horaria_padrao > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Turmas — apenas 3 turmas conforme regra de negocio (RN04)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_turma (
    pk_turma            INT         NOT NULL AUTO_INCREMENT,
    nome_turma          VARCHAR(50) NOT NULL,
    turno               ENUM('Manha','Tarde') NOT NULL,
    faixa_etaria_inicio INT         NOT NULL,
    faixa_etaria_fim    INT         NOT NULL,
    capacidade_max      INT         NOT NULL DEFAULT 40,
    ano_letivo          INT         NOT NULL,
    status_turma        ENUM('ativa','encerrada') NOT NULL DEFAULT 'ativa',
    data_criacao        DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_turma),
    UNIQUE KEY uq_turma_ano (nome_turma, ano_letivo),
    CONSTRAINT chk_capacidade_max      CHECK (capacidade_max      > 0),
    CONSTRAINT chk_faixa_etaria_inicio CHECK (faixa_etaria_inicio >= 8),
    CONSTRAINT chk_faixa_etaria_fim    CHECK (faixa_etaria_fim    <= 14)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Programas sociais que custeiam o CCA
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_programa_social (
    pk_programa   INT          NOT NULL AUTO_INCREMENT,
    nome_programa VARCHAR(50)  NOT NULL,
    descricao     VARCHAR(200),
    data_criacao  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_programa),
    UNIQUE KEY uq_nome_programa (nome_programa)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Categorias de gastos financeiros
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_categoria_gastos (
    pk_categoria   INT          NOT NULL AUTO_INCREMENT,
    nome_categoria VARCHAR(60)  NOT NULL,
    descricao      VARCHAR(150),
    data_criacao   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_categoria),
    UNIQUE KEY uq_nome_categoria (nome_categoria)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Contas bancarias da instituicao
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_conta (
    pk_conta     INT           NOT NULL AUTO_INCREMENT,
    nome_conta   VARCHAR(50)   NOT NULL,
    banco        VARCHAR(60)   NOT NULL,
    agencia      CHAR(10)      NOT NULL,
    numero_conta VARCHAR(20)   NOT NULL,
    saldo        DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    data_criacao DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_conta),
    UNIQUE KEY uq_numero_conta (numero_conta),
    CONSTRAINT chk_saldo CHECK (saldo >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ================================================================
-- TABELAS DEPENDENTES — Modulo RH
-- ================================================================

-- ----------------------------------------------------------------
-- Funcionarios (professores, coordenadores, equipe administrativa)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_funcionario (
    pk_funcionario        INT           NOT NULL AUTO_INCREMENT,
    cpf_funcionario       CHAR(11)      NOT NULL,
    fk_cargo              INT           NOT NULL,
    nome_funcionario      VARCHAR(50)   NOT NULL,
    data_admissao         DATE          NOT NULL,
    tipo_vinculo          ENUM('CLT','Estatutario','Voluntario') NOT NULL DEFAULT 'CLT',
    salario               DECIMAL(10,2) NOT NULL,
    carga_horaria_semanal INT           NOT NULL,
    status_funcionario    ENUM('ativo','afastado','desligado')   NOT NULL DEFAULT 'ativo',
    data_criacao          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_funcionario),
    UNIQUE KEY uq_cpf_funcionario (cpf_funcionario),
    FOREIGN KEY (fk_cargo) REFERENCES tb_cargo(pk_cargo)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_cpf_funcionario       CHECK (cpf_funcionario       REGEXP '^[0-9]{11}$'),
    CONSTRAINT chk_salario               CHECK (salario               > 0),
    CONSTRAINT chk_carga_horaria_semanal CHECK (carga_horaria_semanal > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Contatos do responsavel (telefone e/ou e-mail — multiplos por responsavel)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_contato_responsavel (
    pk_contato_responsavel INT          NOT NULL AUTO_INCREMENT,
    fk_responsavel         INT          NOT NULL,
    tipo_contato           ENUM('telefone','email') NOT NULL,
    valor_contato          VARCHAR(120) NOT NULL,
    principal              BOOLEAN      NOT NULL DEFAULT 0,
    data_criacao           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_contato_responsavel),
    UNIQUE KEY uq_contato_responsavel (fk_responsavel, valor_contato),
    FOREIGN KEY (fk_responsavel) REFERENCES tb_responsavel(pk_responsavel)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Contatos do funcionario (telefone e/ou e-mail)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_contato_funcionario (
    pk_contato_funcionario INT          NOT NULL AUTO_INCREMENT,
    fk_funcionario         INT          NOT NULL,
    tipo_contato           ENUM('telefone','email') NOT NULL,
    valor_contato          VARCHAR(120) NOT NULL,
    principal              BOOLEAN      NOT NULL DEFAULT 0,
    data_criacao           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_contato_funcionario),
    UNIQUE KEY uq_contato_funcionario (fk_funcionario, valor_contato),
    FOREIGN KEY (fk_funcionario) REFERENCES tb_funcionario(pk_funcionario)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Relacionamento aluno-responsavel N:N
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_aluno_responsavel (
    pk_aluno_responsavel INT      NOT NULL AUTO_INCREMENT,
    fk_aluno             INT      NOT NULL,
    fk_responsavel       INT      NOT NULL,
    parentesco           ENUM('Pai','Mae','Avo','Ava','Tio','Tia',
                              'Padrasto','Madrasta','Tutor',
                              'Responsavel Legal','Outro') NOT NULL,
    responsavel_legal    BOOLEAN  NOT NULL DEFAULT 0,
    data_criacao         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_aluno_responsavel),
    UNIQUE KEY uq_aluno_responsavel (fk_aluno, fk_responsavel),
    FOREIGN KEY (fk_aluno)       REFERENCES tb_aluno(pk_aluno)
        ON DELETE CASCADE  ON UPDATE CASCADE,
    FOREIGN KEY (fk_responsavel) REFERENCES tb_responsavel(pk_responsavel)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Vinculo familiar entre alunos (ex: irmaos na mesma instituicao)
-- CHECK fk_aluno_1 <> fk_aluno_2 implementado em trigger (MySQL 8 erro 3823)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_vinculo_familiar (
    pk_vinculo   INT      NOT NULL AUTO_INCREMENT,
    fk_aluno_1   INT      NOT NULL,
    fk_aluno_2   INT      NOT NULL,
    tipo_vinculo ENUM('irmao','gemeo','primo','outro') NOT NULL DEFAULT 'irmao',
    data_criacao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_vinculo),
    UNIQUE KEY uq_vinculo_familiar (fk_aluno_1, fk_aluno_2),
    FOREIGN KEY (fk_aluno_1) REFERENCES tb_aluno(pk_aluno)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (fk_aluno_2) REFERENCES tb_aluno(pk_aluno)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Matriculas dos alunos nas turmas
-- UNIQUE KEY uq_matricula_ativa: impede duplicidade por aluno/turma
--   na idempotencia do DML (INSERT IGNORE usa esta chave)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_matricula (
    pk_matricula       INT      NOT NULL AUTO_INCREMENT,
    fk_aluno           INT      NOT NULL,
    fk_turma           INT      NOT NULL,
    data_matricula     DATE     NOT NULL,
    situacao_matricula ENUM('ativa','cancelada','concluida') NOT NULL DEFAULT 'ativa',
    data_encerramento  DATE,
    data_criacao       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_matricula),
    -- Garante idempotencia do DML: mesmo aluno na mesma turma na mesma data = 1 registro
    UNIQUE KEY uq_matricula (fk_aluno, fk_turma, data_matricula),
    FOREIGN KEY (fk_aluno) REFERENCES tb_aluno(pk_aluno)
        ON DELETE CASCADE  ON UPDATE CASCADE,
    FOREIGN KEY (fk_turma) REFERENCES tb_turma(pk_turma)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Lista de espera (max 40 alunos — RN05)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_lista_espera (
    pk_lista_espera  INT      NOT NULL AUTO_INCREMENT,
    fk_aluno         INT      NOT NULL,
    fk_turma         INT      NOT NULL,
    data_solicitacao DATE     NOT NULL,
    status_espera    ENUM('aguardando','chamado','matriculado','cancelado')
                             NOT NULL DEFAULT 'aguardando',
    data_chamada     DATE,
    data_criacao     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_lista_espera),
    UNIQUE KEY uq_lista_espera (fk_aluno, fk_turma),
    FOREIGN KEY (fk_aluno) REFERENCES tb_aluno(pk_aluno)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (fk_turma) REFERENCES tb_turma(pk_turma)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Repasses dos programas sociais (fonte de custeio) — RN08
-- UNIQUE KEY uq_repasse: impede repasse duplicado do mesmo programa no mesmo mes
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_repasse (
    pk_repasse     INT           NOT NULL AUTO_INCREMENT,
    fk_programa    INT           NOT NULL,
    data_repasse   DATE          NOT NULL,
    valor_repasse  DECIMAL(10,2) NOT NULL,
    mes_referencia CHAR(7)       NOT NULL,
    descricao      VARCHAR(200),
    data_criacao   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_repasse),
    UNIQUE KEY uq_repasse (fk_programa, mes_referencia),
    FOREIGN KEY (fk_programa) REFERENCES tb_programa_social(pk_programa)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_valor_repasse    CHECK (valor_repasse    > 0),
    CONSTRAINT chk_mes_ref_repasse  CHECK (mes_referencia REGEXP '^[0-9]{4}-[0-9]{2}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Frequencia por dia de aula
-- BI/IA: taxa de presenca e principal feature para previsao de evasao
-- fk_repasse: integracao direta Academico + Financeiro
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_frequencia (
    pk_frequencia INT      NOT NULL AUTO_INCREMENT,
    fk_matricula  INT      NOT NULL,
    fk_repasse    INT      DEFAULT NULL,
    data_aula     DATE     NOT NULL,
    presente      BOOLEAN  NOT NULL DEFAULT 1,
    motivo_falta  VARCHAR(100),
    data_criacao  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_frequencia),
    UNIQUE KEY uq_frequencia (fk_matricula, data_aula),
    FOREIGN KEY (fk_matricula) REFERENCES tb_matricula(pk_matricula)
        ON DELETE CASCADE  ON UPDATE CASCADE,
    FOREIGN KEY (fk_repasse)   REFERENCES tb_repasse(pk_repasse)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Jornada de trabalho dos funcionarios
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_jornada_trabalho (
    pk_jornada     INT      NOT NULL AUTO_INCREMENT,
    fk_funcionario INT      NOT NULL,
    dia_semana     ENUM('Segunda','Terca','Quarta','Quinta','Sexta') NOT NULL,
    hora_entrada   TIME     NOT NULL,
    hora_saida     TIME     NOT NULL,
    data_criacao   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_jornada),
    UNIQUE KEY uq_jornada (fk_funcionario, dia_semana),
    FOREIGN KEY (fk_funcionario) REFERENCES tb_funcionario(pk_funcionario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_hora_saida CHECK (hora_saida > hora_entrada)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Registro de ponto dos funcionarios
-- hora_entrada NOT NULL: entrada sempre obrigatoria
-- hora_saida nullable: funcionario pode ainda nao ter saido
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_registro_ponto (
    pk_registro_ponto INT      NOT NULL AUTO_INCREMENT,
    fk_funcionario    INT      NOT NULL,
    data_registro     DATE     NOT NULL,
    hora_entrada      TIME     NOT NULL,
    hora_saida        TIME,
    data_criacao      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_registro_ponto),
    UNIQUE KEY uq_registro_ponto (fk_funcionario, data_registro),
    FOREIGN KEY (fk_funcionario) REFERENCES tb_funcionario(pk_funcionario)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Entidade associativa professor-turma N:N (RN07)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_professor_turma (
    pk_professor_turma INT      NOT NULL AUTO_INCREMENT,
    fk_funcionario     INT      NOT NULL,
    fk_turma           INT      NOT NULL,
    data_criacao       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_professor_turma),
    UNIQUE KEY uq_professor_turma (fk_funcionario, fk_turma),
    FOREIGN KEY (fk_funcionario) REFERENCES tb_funcionario(pk_funcionario)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (fk_turma)       REFERENCES tb_turma(pk_turma)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Alertas de risco — integracao Academico + RH
-- BI/IA: tipo_alerta e nivel_risco sao features preditivas de evasao
-- UNIQUE KEY uq_alerta: impede alerta duplicado do mesmo tipo para
--   o mesmo aluno na mesma data
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_alerta (
    pk_alerta        INT          NOT NULL AUTO_INCREMENT,
    fk_aluno         INT          NOT NULL,
    fk_funcionario   INT          NOT NULL,
    tipo_alerta      ENUM('Frequencia Critica','Vulnerabilidade','Evasao Iminente') NOT NULL,
    nivel_risco      ENUM('Baixo','Medio','Alto','Critico') NOT NULL DEFAULT 'Medio',
    descricao_alerta VARCHAR(200) NOT NULL,
    data_alerta      DATE         NOT NULL,
    status_alerta    ENUM('Aberto','Em Acompanhamento','Resolvido') NOT NULL DEFAULT 'Aberto',
    data_resolucao   DATE,
    data_criacao     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_alerta),
    UNIQUE KEY uq_alerta (fk_aluno, tipo_alerta, data_alerta),
    FOREIGN KEY (fk_aluno)       REFERENCES tb_aluno(pk_aluno)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (fk_funcionario) REFERENCES tb_funcionario(pk_funcionario)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ================================================================
-- TABELAS DEPENDENTES — Modulo Financeiro
-- ================================================================

-- ----------------------------------------------------------------
-- Gastos operacionais vinculados a repasses
-- UNIQUE KEY uq_gasto: mesma nota fiscal nao pode ser lancada duas vezes
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_gasto (
    pk_gasto     INT           NOT NULL AUTO_INCREMENT,
    fk_repasse   INT           NOT NULL,
    fk_categoria INT           NOT NULL,
    data_gasto   DATE          NOT NULL,
    valor_gasto  DECIMAL(10,2) NOT NULL,
    descricao    VARCHAR(200),
    nota_fiscal  VARCHAR(50),
    data_criacao DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_gasto),
    UNIQUE KEY uq_gasto (fk_repasse, nota_fiscal),
    FOREIGN KEY (fk_repasse)   REFERENCES tb_repasse(pk_repasse)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (fk_categoria) REFERENCES tb_categoria_gastos(pk_categoria)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_valor_gasto CHECK (valor_gasto > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Faturas a pagar (contas fixas, servicos, etc.)
-- UNIQUE KEY uq_fatura: mesma descricao na mesma data de vencimento = 1 fatura
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_fatura (
    pk_fatura       INT           NOT NULL AUTO_INCREMENT,
    fk_categoria    INT           NOT NULL,
    descricao       VARCHAR(200)  NOT NULL,
    valor_fatura    DECIMAL(10,2) NOT NULL,
    data_vencimento DATE          NOT NULL,
    status_fatura   ENUM('pendente','paga','vencida') NOT NULL DEFAULT 'pendente',
    data_criacao    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_fatura),
    UNIQUE KEY uq_fatura (fk_categoria, descricao, data_vencimento),
    FOREIGN KEY (fk_categoria) REFERENCES tb_categoria_gastos(pk_categoria)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_valor_fatura CHECK (valor_fatura > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Pagamentos de faturas vinculados a conta bancaria
-- UNIQUE KEY uq_pagamento_fatura: cada fatura so pode ser paga uma vez
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_pagamento_fatura (
    pk_pagamento_fatura INT           NOT NULL AUTO_INCREMENT,
    fk_fatura           INT           NOT NULL,
    fk_conta            INT           NOT NULL,
    data_pagamento      DATE          NOT NULL,
    valor_pago          DECIMAL(10,2) NOT NULL,
    data_criacao        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_pagamento_fatura),
    UNIQUE KEY uq_pagamento_fatura (fk_fatura),
    FOREIGN KEY (fk_fatura) REFERENCES tb_fatura(pk_fatura)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (fk_conta)  REFERENCES tb_conta(pk_conta)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_valor_pago_fatura CHECK (valor_pago > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Pagamento mensal de funcionarios — integracao RH + Financeiro (RN08)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tb_pagamento_funcionario (
    pk_pagamento     INT           NOT NULL AUTO_INCREMENT,
    fk_funcionario   INT           NOT NULL,
    fk_repasse       INT           NOT NULL,
    mes_referencia   CHAR(7)       NOT NULL,
    valor_pago       DECIMAL(10,2) NOT NULL,
    data_pagamento   DATE          NOT NULL,
    status_pagamento ENUM('pendente','pago') NOT NULL DEFAULT 'pendente',
    data_criacao     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_pagamento),
    UNIQUE KEY uq_pagamento_funcionario (fk_funcionario, mes_referencia),
    FOREIGN KEY (fk_funcionario) REFERENCES tb_funcionario(pk_funcionario)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (fk_repasse)     REFERENCES tb_repasse(pk_repasse)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_valor_pago_func  CHECK (valor_pago     > 0),
    CONSTRAINT chk_mes_ref_pgto     CHECK (mes_referencia REGEXP '^[0-9]{4}-[0-9]{2}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ================================================================
-- VIEWS OLTP
-- ================================================================

-- ----------------------------------------------------------------
-- Alunos com codigo formatado e idade calculada dinamicamente
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW vw_aluno AS
SELECT
    pk_aluno,
    CONCAT('CA', LPAD(pk_aluno, 6, '0'))           AS codigo_aluno,
    nome_aluno,
    nis_aluno,
    cpf_aluno,
    sexo,
    data_nascimento,
    TIMESTAMPDIFF(YEAR, data_nascimento, CURDATE()) AS idade,
    raca_cor,
    situacao_aluno
FROM tb_aluno;

-- ----------------------------------------------------------------
-- Saldo disponivel por repasse (subqueries correlacionadas)
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW vw_saldo_repasse AS
SELECT
    r.pk_repasse,
    r.mes_referencia,
    p.nome_programa,
    r.valor_repasse,
    IFNULL((SELECT SUM(g.valor_gasto)
            FROM tb_gasto g
            WHERE g.fk_repasse = r.pk_repasse), 0)         AS total_gastos,
    IFNULL((SELECT SUM(pf.valor_pago)
            FROM tb_pagamento_funcionario pf
            WHERE pf.fk_repasse = r.pk_repasse), 0)        AS total_pagamentos,
    r.valor_repasse
        - IFNULL((SELECT SUM(g.valor_gasto)
                  FROM tb_gasto g
                  WHERE g.fk_repasse = r.pk_repasse), 0)
        - IFNULL((SELECT SUM(pf.valor_pago)
                  FROM tb_pagamento_funcionario pf
                  WHERE pf.fk_repasse = r.pk_repasse), 0)  AS saldo_disponivel
FROM tb_repasse r
JOIN tb_programa_social p ON p.pk_programa = r.fk_programa;

-- ----------------------------------------------------------------
-- Ocupacao das turmas em tempo real
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW vw_ocupacao_turmas AS
SELECT
    t.pk_turma,
    t.nome_turma,
    t.turno,
    t.faixa_etaria_inicio,
    t.faixa_etaria_fim,
    t.capacidade_max,
    COUNT(m.pk_matricula)                            AS alunos_matriculados,
    t.capacidade_max - COUNT(m.pk_matricula)         AS vagas_disponiveis,
    (SELECT COUNT(*) FROM tb_lista_espera le
     WHERE le.fk_turma    = t.pk_turma
       AND le.status_espera = 'aguardando')          AS alunos_em_espera
FROM tb_turma t
LEFT JOIN tb_matricula m
       ON m.fk_turma = t.pk_turma AND m.situacao_matricula = 'ativa'
GROUP BY t.pk_turma, t.nome_turma, t.turno,
         t.faixa_etaria_inicio, t.faixa_etaria_fim, t.capacidade_max;

-- ----------------------------------------------------------------
-- Total de pessoas na instituicao — controle do limite de 200 (RN03)
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW vw_total_instituicao AS
SELECT
    (SELECT COUNT(*) FROM tb_matricula   WHERE situacao_matricula = 'ativa') AS total_alunos_ativos,
    (SELECT COUNT(*) FROM tb_funcionario WHERE status_funcionario = 'ativo') AS total_funcionarios_ativos,
    (SELECT COUNT(*) FROM tb_matricula   WHERE situacao_matricula = 'ativa')
    + (SELECT COUNT(*) FROM tb_funcionario WHERE status_funcionario = 'ativo') AS total_pessoas;


-- ================================================================
-- TRIGGERS
-- ================================================================

DELIMITER $$

-- ----------------------------------------------------------------
-- BLOCO 1: Validacao de CPF (RN10)
-- ----------------------------------------------------------------

CREATE TRIGGER trg_cpf_aluno_insert
BEFORE INSERT ON tb_aluno FOR EACH ROW
BEGIN
    IF fn_validar_cpf(NEW.cpf_aluno) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CPF do aluno invalido.';
    END IF;
END$$

CREATE TRIGGER trg_cpf_aluno_update
BEFORE UPDATE ON tb_aluno FOR EACH ROW
BEGIN
    IF fn_validar_cpf(NEW.cpf_aluno) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CPF do aluno invalido.';
    END IF;
END$$

CREATE TRIGGER trg_cpf_responsavel_insert
BEFORE INSERT ON tb_responsavel FOR EACH ROW
BEGIN
    IF fn_validar_cpf(NEW.cpf_responsavel) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CPF do responsavel invalido.';
    END IF;
END$$

CREATE TRIGGER trg_cpf_responsavel_update
BEFORE UPDATE ON tb_responsavel FOR EACH ROW
BEGIN
    IF fn_validar_cpf(NEW.cpf_responsavel) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CPF do responsavel invalido.';
    END IF;
END$$

CREATE TRIGGER trg_cpf_funcionario_insert
BEFORE INSERT ON tb_funcionario FOR EACH ROW
BEGIN
    IF fn_validar_cpf(NEW.cpf_funcionario) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CPF do funcionario invalido.';
    END IF;
END$$

CREATE TRIGGER trg_cpf_funcionario_update
BEFORE UPDATE ON tb_funcionario FOR EACH ROW
BEGIN
    IF fn_validar_cpf(NEW.cpf_funcionario) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CPF do funcionario invalido.';
    END IF;
END$$

-- ----------------------------------------------------------------
-- BLOCO 2: Validacao de contatos (telefone e e-mail)
-- ----------------------------------------------------------------

CREATE TRIGGER trg_contato_responsavel_insert
BEFORE INSERT ON tb_contato_responsavel FOR EACH ROW
BEGIN
    IF NEW.tipo_contato = 'telefone' AND fn_validar_telefone(NEW.valor_contato) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Telefone do responsavel invalido. Use: (XX) XXXXX-XXXX';
    END IF;
    IF NEW.tipo_contato = 'email' AND fn_validar_email(NEW.valor_contato) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'E-mail do responsavel invalido.';
    END IF;
END$$

CREATE TRIGGER trg_contato_responsavel_update
BEFORE UPDATE ON tb_contato_responsavel FOR EACH ROW
BEGIN
    IF NEW.tipo_contato = 'telefone' AND fn_validar_telefone(NEW.valor_contato) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Telefone do responsavel invalido. Use: (XX) XXXXX-XXXX';
    END IF;
    IF NEW.tipo_contato = 'email' AND fn_validar_email(NEW.valor_contato) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'E-mail do responsavel invalido.';
    END IF;
END$$

CREATE TRIGGER trg_contato_funcionario_insert
BEFORE INSERT ON tb_contato_funcionario FOR EACH ROW
BEGIN
    IF NEW.tipo_contato = 'telefone' AND fn_validar_telefone(NEW.valor_contato) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Telefone do funcionario invalido. Use: (XX) XXXXX-XXXX';
    END IF;
    IF NEW.tipo_contato = 'email' AND fn_validar_email(NEW.valor_contato) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'E-mail do funcionario invalido.';
    END IF;
END$$

-- ----------------------------------------------------------------
-- BLOCO 3: Validacao de vinculo familiar
-- ----------------------------------------------------------------

CREATE TRIGGER trg_vinculo_mesmo_aluno
BEFORE INSERT ON tb_vinculo_familiar FOR EACH ROW
BEGIN
    IF NEW.fk_aluno_1 = NEW.fk_aluno_2 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Um aluno nao pode ter vinculo familiar consigo mesmo.';
    END IF;
END$$

-- ----------------------------------------------------------------
-- BLOCO 4: Validacao de idade do aluno (RN01)
-- ----------------------------------------------------------------

CREATE TRIGGER trg_validar_idade_aluno_insert
BEFORE INSERT ON tb_aluno FOR EACH ROW
BEGIN
    DECLARE v_idade INT;
    SET v_idade = TIMESTAMPDIFF(YEAR, NEW.data_nascimento, CURDATE());
    IF v_idade < 8 OR v_idade > 14 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Aluno deve ter entre 8 e 14 anos para ingresso.';
    END IF;
END$$

-- Valida SOMENTE quando data_nascimento e alterada
-- Evita bloqueio do sp_encerrar_alunos_14_anos (RN06)
CREATE TRIGGER trg_validar_idade_aluno_update
BEFORE UPDATE ON tb_aluno FOR EACH ROW
BEGIN
    DECLARE v_idade INT;
    IF NEW.data_nascimento <> OLD.data_nascimento THEN
        SET v_idade = TIMESTAMPDIFF(YEAR, NEW.data_nascimento, CURDATE());
        IF v_idade < 8 OR v_idade > 14 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Faixa etaria invalida para alteracao de data de nascimento.';
        END IF;
    END IF;
END$$

-- ----------------------------------------------------------------
-- BLOCO 5: Regras de matricula
-- ----------------------------------------------------------------

-- RN02: Aluno nao pode ter duas matriculas ativas ao mesmo tempo
CREATE TRIGGER trg_matricula_unica_insert
BEFORE INSERT ON tb_matricula FOR EACH ROW
BEGIN
    DECLARE v_ativas INT;
    IF NEW.situacao_matricula = 'ativa' THEN
        SELECT COUNT(*) INTO v_ativas
        FROM tb_matricula
        WHERE fk_aluno = NEW.fk_aluno AND situacao_matricula = 'ativa';
        IF v_ativas > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Aluno ja possui matricula ativa. Encerre-a antes de criar nova.';
        END IF;
    END IF;
END$$

-- RN09: Idade do aluno deve ser compativel com a faixa etaria da turma
CREATE TRIGGER trg_validar_turma_por_idade_insert
BEFORE INSERT ON tb_matricula FOR EACH ROW
BEGIN
    DECLARE v_nascimento   DATE;
    DECLARE v_idade        INT;
    DECLARE v_faixa_inicio INT;
    DECLARE v_faixa_fim    INT;

    IF NEW.situacao_matricula = 'ativa' THEN
        SELECT data_nascimento INTO v_nascimento
        FROM tb_aluno WHERE pk_aluno = NEW.fk_aluno;

        SET v_idade = TIMESTAMPDIFF(YEAR, v_nascimento, CURDATE());

        SELECT faixa_etaria_inicio, faixa_etaria_fim
        INTO   v_faixa_inicio, v_faixa_fim
        FROM   tb_turma WHERE pk_turma = NEW.fk_turma;

        IF v_faixa_fim = 14 THEN
            IF v_idade < v_faixa_inicio OR v_idade > 14 THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Idade do aluno nao compativel com a faixa etaria da turma.';
            END IF;
        ELSE
            IF v_idade < v_faixa_inicio OR v_idade >= v_faixa_fim THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Idade do aluno nao compativel com a faixa etaria da turma.';
            END IF;
        END IF;
    END IF;
END$$

-- RN04: Capacidade maxima por turma
CREATE TRIGGER trg_capacidade_turma_insert
BEFORE INSERT ON tb_matricula FOR EACH ROW
BEGIN
    DECLARE v_cap_max      INT;
    DECLARE v_matriculados INT;

    IF NEW.situacao_matricula = 'ativa' THEN
        SELECT capacidade_max INTO v_cap_max
        FROM tb_turma WHERE pk_turma = NEW.fk_turma;

        SELECT COUNT(*) INTO v_matriculados
        FROM tb_matricula
        WHERE fk_turma = NEW.fk_turma AND situacao_matricula = 'ativa';

        IF v_matriculados >= v_cap_max THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Turma atingiu capacidade maxima. Adicione o aluno a lista de espera.';
        END IF;
    END IF;
END$$

-- RN03: Limite total de 200 pessoas (alunos ativos + funcionarios ativos)
CREATE TRIGGER trg_limite_instituicao
BEFORE INSERT ON tb_matricula FOR EACH ROW
BEGIN
    DECLARE v_alunos       INT;
    DECLARE v_funcionarios INT;

    IF NEW.situacao_matricula = 'ativa' THEN
        SELECT COUNT(*) INTO v_alunos
        FROM tb_matricula WHERE situacao_matricula = 'ativa';

        SELECT COUNT(*) INTO v_funcionarios
        FROM tb_funcionario WHERE status_funcionario = 'ativo';

        IF (v_alunos + v_funcionarios + 1) > 200 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Limite total da instituicao atingido (max 200 pessoas).';
        END IF;
    END IF;
END$$

-- RN05 (parte 1): Bloquear insercao direta quando ha fila ativa para a turma
CREATE TRIGGER trg_bloquear_insercao_com_fila
BEFORE INSERT ON tb_matricula FOR EACH ROW
BEGIN
    DECLARE v_fila INT;

    IF NEW.situacao_matricula = 'ativa'
       AND (@from_waitlist IS NULL OR @from_waitlist = 0) THEN

        SELECT COUNT(*) INTO v_fila
        FROM tb_lista_espera
        WHERE fk_turma = NEW.fk_turma AND status_espera = 'aguardando';

        IF v_fila > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ha alunos na lista de espera. A matricula sera processada automaticamente quando houver vaga.';
        END IF;
    END IF;
END$$

-- RN05 (parte 2): Chamar proximo aluno da fila quando vaga surge
-- Prioridade LIFO (mais recente primeiro) — turma atribuida pela idade atual
CREATE TRIGGER trg_chamar_lista_espera
AFTER UPDATE ON tb_matricula FOR EACH ROW
BEGIN
    DECLARE v_espera_id     INT DEFAULT NULL;
    DECLARE v_aluno_id      INT DEFAULT NULL;
    DECLARE v_nascimento    DATE;
    DECLARE v_idade         INT;
    DECLARE v_turma_correta INT DEFAULT NULL;
    DECLARE v_cap_max       INT DEFAULT 0;
    DECLARE v_matriculados  INT DEFAULT 0;

    DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

    IF OLD.situacao_matricula = 'ativa'
       AND NEW.situacao_matricula IN ('cancelada','concluida') THEN

        -- LIFO: busca o aluno MAIS RECENTE da fila (RN05)
        SELECT pk_lista_espera, fk_aluno
        INTO   v_espera_id, v_aluno_id
        FROM   tb_lista_espera
        WHERE  fk_turma      = OLD.fk_turma
          AND  status_espera = 'aguardando'
        ORDER BY data_solicitacao DESC
        LIMIT 1;

        IF v_aluno_id IS NOT NULL THEN

            SELECT data_nascimento INTO v_nascimento
            FROM tb_aluno WHERE pk_aluno = v_aluno_id;

            SET v_idade = TIMESTAMPDIFF(YEAR, v_nascimento, CURDATE());

            -- Determina turma correta pela idade atual do aluno (RN05)
            IF v_idade >= 8 AND v_idade < 10 THEN
                SELECT pk_turma INTO v_turma_correta
                FROM tb_turma
                WHERE faixa_etaria_inicio = 8 AND faixa_etaria_fim = 10
                  AND status_turma = 'ativa' LIMIT 1;

            ELSEIF v_idade >= 10 AND v_idade < 12 THEN
                SELECT pk_turma INTO v_turma_correta
                FROM tb_turma
                WHERE faixa_etaria_inicio = 10 AND faixa_etaria_fim = 12
                  AND status_turma = 'ativa' LIMIT 1;

            ELSEIF v_idade >= 12 AND v_idade <= 14 THEN
                SELECT pk_turma INTO v_turma_correta
                FROM tb_turma
                WHERE faixa_etaria_inicio = 12 AND faixa_etaria_fim = 14
                  AND status_turma = 'ativa' LIMIT 1;

            ELSE
                SET v_turma_correta = NULL;
            END IF;

            IF v_turma_correta IS NOT NULL THEN

                SELECT capacidade_max INTO v_cap_max
                FROM tb_turma WHERE pk_turma = v_turma_correta;

                SELECT COUNT(*) INTO v_matriculados
                FROM tb_matricula
                WHERE fk_turma = v_turma_correta AND situacao_matricula = 'ativa';

                IF v_matriculados < v_cap_max THEN
                    SET @from_waitlist = 1;

                    INSERT INTO tb_matricula (fk_aluno, fk_turma, data_matricula, situacao_matricula)
                    VALUES (v_aluno_id, v_turma_correta, CURDATE(), 'ativa');

                    SET @from_waitlist = 0;

                    UPDATE tb_lista_espera
                    SET    status_espera = 'matriculado',
                           data_chamada  = CURDATE()
                    WHERE  pk_lista_espera = v_espera_id;
                END IF;

            ELSE
                -- Aluno com 14+ anos: cancela fila e encerra participacao (RN06)
                UPDATE tb_lista_espera
                SET    status_espera = 'cancelado',
                       data_chamada  = CURDATE()
                WHERE  pk_lista_espera = v_espera_id;

                UPDATE tb_aluno
                SET    situacao_aluno = 'concluido'
                WHERE  pk_aluno = v_aluno_id;
            END IF;
        END IF;
    END IF;
END$$

-- ----------------------------------------------------------------
-- BLOCO 6: Limite da lista de espera — max 40 alunos (RN05)
-- ----------------------------------------------------------------

CREATE TRIGGER trg_limite_lista_espera
BEFORE INSERT ON tb_lista_espera FOR EACH ROW
BEGIN
    DECLARE v_total INT;

    IF NEW.status_espera = 'aguardando' THEN
        SELECT COUNT(*) INTO v_total
        FROM tb_lista_espera WHERE status_espera = 'aguardando';

        IF v_total >= 40 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Lista de espera atingiu o limite maximo de 40 alunos.';
        END IF;
    END IF;
END$$

DELIMITER ;


-- ================================================================
-- STORED PROCEDURE + EVENT: Encerramento de alunos com 14 anos (RN06)
-- ================================================================

DELIMITER $$

CREATE PROCEDURE sp_encerrar_alunos_14_anos()
BEGIN
    -- Encerra matriculas de alunos que completaram 14 anos
    UPDATE tb_matricula m
    JOIN   tb_aluno a ON a.pk_aluno = m.fk_aluno
    SET    m.situacao_matricula = 'concluida',
           m.data_encerramento  = CURDATE()
    WHERE  TIMESTAMPDIFF(YEAR, a.data_nascimento, CURDATE()) >= 14
      AND  m.situacao_matricula = 'ativa';

    -- Atualiza situacao do aluno
    UPDATE tb_aluno
    SET    situacao_aluno = 'concluido'
    WHERE  TIMESTAMPDIFF(YEAR, data_nascimento, CURDATE()) >= 14
      AND  situacao_aluno = 'ativo';
END$$

DELIMITER ;

-- Habilita agendador de eventos
SET GLOBAL event_scheduler = ON;

CREATE EVENT IF NOT EXISTS evt_encerrar_alunos_14_anos
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
DO CALL sp_encerrar_alunos_14_anos();

-- ================================================================
-- Confirmacao da estrutura criada
-- ================================================================
SELECT TABLE_NAME, TABLE_ROWS, ENGINE
FROM   information_schema.TABLES
WHERE  TABLE_SCHEMA = 'sisgesc_publico_nota'
ORDER BY TABLE_NAME;