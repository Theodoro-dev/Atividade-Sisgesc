-- ================================================================
-- SisGESC - Sistema de Gestao Educacional e Social
-- CCA Bom Jesus do Cangaiba
-- ================================================================
-- REGRAS DE NEGOCIO:
-- RN01 Aluno deve ter entre 8 e 14 anos (calculado via data_nascimento)
-- RN02 Um aluno so pode ter UMA matricula ativa por vez
-- RN03 Limite total de 200 pessoas (alunos ativos + funcionarios ativos)
-- RN04 Capacidade por turma: Turma1=50, Turma2=60, Turma3=60
-- RN05 Lista de espera max 40; insercao direta bloqueada com fila ativa;
--      prioridade LIFO; turma atribuida pela idade atual do aluno
-- RN06 Aluno com 14 anos completos e encerrado automaticamente
-- RN07 Professor pode atuar em multiplas turmas (N:N)
-- RN08 Pagamento de funcionario vinculado ao repasse do programa social
-- RN09 Idade do aluno deve ser compativel com a faixa etaria da turma
-- RN10 CPF validado com algoritmo de digito verificador
--
-- CAMPOS PARA BI/IA (PREVISAO DE EVASAO):
--   tb_frequencia.presente         taxa de presenca por aluno/turma
--   tb_frequencia.fk_repasse       vinculo direto Academico-Financeiro
--   tb_alerta.tipo_alerta          sinalizacoes de risco de evasao
--   tb_alerta.nivel_risco          grau de urgencia
--   tb_aluno.situacao_aluno        status atual do aluno
--   tb_matricula.situacao_matricula historico de cancelamentos
--   tb_aluno.data_nascimento       calculo de faixa etaria dinamica
--   tb_lista_espera.data_solicitacao tempo de espera na fila
--
-- NOTA DE NOMENCLATURA:
-- As tabelas deste projeto adotam nomes no singular (tb_aluno,
-- tb_turma, etc.) seguindo a convencao de que cada tabela representa
-- o modelo de UMA entidade. O Dicionario de Dados e o DER estao
-- sincronizados com este padrao.
-- ================================================================

CREATE DATABASE IF NOT EXISTS sisgesc_publico_nota_dois
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE sisgesc_publico_nota_dois;

SET @from_waitlist = 0;

-- ================================================================
-- FUNCOES DE VALIDACAO
-- ================================================================

DELIMITER $

-- RN10: Validacao de CPF com calculo de digito verificador
CREATE FUNCTION fn_validar_cpf(p_cpf CHAR(11))
RETURNS TINYINT
DETERMINISTIC
BEGIN
    DECLARE v_soma  INT DEFAULT 0;
    DECLARE v_resto INT;
    DECLARE v_i     INT DEFAULT 1;
    DECLARE v_dig1  INT;
    DECLARE v_dig2  INT;

    IF LENGTH(p_cpf) <> 11 OR p_cpf REGEXP '[^0-9]' THEN RETURN 0; END IF;

    IF p_cpf IN (
        '00000000000','11111111111','22222222222','33333333333',
        '44444444444','55555555555','66666666666','77777777777',
        '88888888888','99999999999','12345678909'
    ) THEN RETURN 0; END IF;

    SET v_soma = 0; SET v_i = 1;
    WHILE v_i <= 9 DO
        SET v_soma = v_soma + CAST(SUBSTRING(p_cpf,v_i,1) AS UNSIGNED) * (11 - v_i);
        SET v_i = v_i + 1;
    END WHILE;
    SET v_resto = v_soma % 11;
    SET v_dig1  = IF(v_resto < 2, 0, 11 - v_resto);

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
END$

-- Validacao de e-mail: formato basico usuario@dominio.tld
CREATE FUNCTION fn_validar_email(p_email VARCHAR(120))
RETURNS TINYINT
DETERMINISTIC
BEGIN
    IF p_email REGEXP '^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$'
    THEN RETURN 1; ELSE RETURN 0; END IF;
END$

-- Validacao de telefone brasileiro: (XX) XXXX-XXXX ou (XX) XXXXX-XXXX
CREATE FUNCTION fn_validar_telefone(p_tel VARCHAR(20))
RETURNS TINYINT
DETERMINISTIC
BEGIN
    IF p_tel REGEXP '^\\([0-9]{2}\\) [0-9]{4,5}-[0-9]{4}$'
    THEN RETURN 1; ELSE RETURN 0; END IF;
END$

DELIMITER ;


-- ================================================================
-- TABELAS BASE (sem dependencias de FK)
-- ================================================================

-- Alunos atendidos pela instituicao (8 a 14 anos)
CREATE TABLE tb_aluno (
    pk_aluno        INT          NOT NULL AUTO_INCREMENT,
    nome_aluno      VARCHAR(120) NOT NULL,
    nis_aluno       CHAR(11)     NOT NULL,
    cpf_aluno       CHAR(11)     NOT NULL,
    sexo            VARCHAR(10)  NOT NULL,
    data_nascimento DATE         NOT NULL,
    raca_cor        VARCHAR(20)  NOT NULL DEFAULT 'Nao declarada',
    situacao_aluno  VARCHAR(12)  NOT NULL DEFAULT 'ativo',
    data_criacao    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_aluno),
    UNIQUE (nis_aluno),
    UNIQUE (cpf_aluno),
    CHECK (cpf_aluno      REGEXP '^[0-9]{11}$'),
    CHECK (nis_aluno      REGEXP '^[0-9]{11}$'),
    CHECK (sexo           IN ('Masculino','Feminino')),
    CHECK (raca_cor       IN ('Branca','Preta','Parda','Amarela','Indigena','Nao declarada')),
    CHECK (situacao_aluno IN ('ativo','inativo','transferido','concluido'))
);

-- Responsaveis legais dos alunos
CREATE TABLE tb_responsavel (
    pk_responsavel   INT          NOT NULL AUTO_INCREMENT,
    cpf_responsavel  CHAR(11)     NOT NULL,
    nome_responsavel VARCHAR(120) NOT NULL,
    data_criacao     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_responsavel),
    UNIQUE (cpf_responsavel),
    CHECK (cpf_responsavel REGEXP '^[0-9]{11}$')
);

-- Cargos da instituicao
CREATE TABLE tb_cargo (
    pk_cargo             INT          NOT NULL AUTO_INCREMENT,
    nome_cargo           VARCHAR(60)  NOT NULL,
    descricao_cargo      VARCHAR(200),
    carga_horaria_padrao INT          NOT NULL,
    data_criacao         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_cargo),
    UNIQUE (nome_cargo),
    CHECK (carga_horaria_padrao > 0)
);

-- Turmas — apenas 3 turmas conforme regra de negocio da instituicao
CREATE TABLE tb_turma (
    pk_turma            INT         NOT NULL AUTO_INCREMENT,
    nome_turma          VARCHAR(50) NOT NULL,
    turno               VARCHAR(10) NOT NULL,
    faixa_etaria_inicio INT         NOT NULL,
    faixa_etaria_fim    INT         NOT NULL,
    capacidade_max      INT         NOT NULL DEFAULT 40,
    ano_letivo          INT         NOT NULL,
    status_turma        VARCHAR(10) NOT NULL DEFAULT 'ativa',
    data_criacao        DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_turma),
    UNIQUE (nome_turma, ano_letivo),
    CHECK (turno        IN ('Manha','Tarde')),
    CHECK (capacidade_max > 0),
    CHECK (faixa_etaria_inicio >= 8),
    CHECK (faixa_etaria_fim    <= 14),
    CHECK (status_turma IN ('ativa','encerrada'))
);

-- Programas sociais que custeiam o CCA
CREATE TABLE tb_programa_social (
    pk_programa   INT          NOT NULL AUTO_INCREMENT,
    nome_programa VARCHAR(100) NOT NULL,
    descricao     VARCHAR(200),
    data_criacao  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_programa),
    UNIQUE (nome_programa)
);

-- Categorias de gastos financeiros
CREATE TABLE tb_categoria_gastos (
    pk_categoria   INT          NOT NULL AUTO_INCREMENT,
    nome_categoria VARCHAR(60)  NOT NULL,
    descricao      VARCHAR(150),
    data_criacao   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_categoria),
    UNIQUE (nome_categoria)
);

-- Contas bancarias da instituicao
CREATE TABLE tb_conta (
    pk_conta     INT           NOT NULL AUTO_INCREMENT,
    nome_conta   VARCHAR(100)  NOT NULL,
    banco        VARCHAR(60)   NOT NULL,
    agencia      CHAR(10)      NOT NULL,
    numero_conta VARCHAR(20)   NOT NULL,
    saldo        DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    data_criacao DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_conta),
    UNIQUE (numero_conta),
    CHECK (saldo >= 0)
);


-- ================================================================
-- TABELAS DEPENDENTES — Modulo RH
-- ================================================================

-- Funcionarios (professores, coordenadores, equipe administrativa)
CREATE TABLE tb_funcionario (
    pk_funcionario        INT           NOT NULL AUTO_INCREMENT,
    cpf_funcionario       CHAR(11)      NOT NULL,
    fk_cargo              INT           NOT NULL,
    nome_funcionario      VARCHAR(120)  NOT NULL,
    data_admissao         DATE          NOT NULL,
    tipo_vinculo          VARCHAR(15)   NOT NULL DEFAULT 'CLT',
    salario               DECIMAL(10,2) NOT NULL,
    carga_horaria_semanal INT           NOT NULL,
    status_funcionario    VARCHAR(15)   NOT NULL DEFAULT 'ativo',
    data_criacao          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_funcionario),
    UNIQUE (cpf_funcionario),
    FOREIGN KEY (fk_cargo) REFERENCES tb_cargo(pk_cargo)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (cpf_funcionario  REGEXP '^[0-9]{11}$'),
    CHECK (salario > 0),
    CHECK (carga_horaria_semanal > 0),
    CHECK (tipo_vinculo       IN ('CLT','Estatutario','Voluntario')),
    CHECK (status_funcionario IN ('ativo','afastado','desligado'))
);

-- Contatos do responsavel (telefone e/ou e-mail — multiplos por responsavel)
-- CORRECAO: pk_contato → pk_contato_responsavel (padrao pk_nome_da_tabela)
CREATE TABLE tb_contato_responsavel (
    pk_contato_responsavel INT          NOT NULL AUTO_INCREMENT,
    fk_responsavel         INT          NOT NULL,
    tipo_contato           VARCHAR(10)  NOT NULL,
    valor_contato          VARCHAR(120) NOT NULL,
    principal              BOOLEAN      NOT NULL DEFAULT 0,
    data_criacao           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_contato_responsavel),
    FOREIGN KEY (fk_responsavel) REFERENCES tb_responsavel(pk_responsavel)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CHECK (tipo_contato IN ('telefone','email'))
);

-- Contatos do funcionario (telefone e/ou e-mail)
-- CORRECAO: pk_contato_func → pk_contato_funcionario (padrao pk_nome_da_tabela)
CREATE TABLE tb_contato_funcionario (
    pk_contato_funcionario INT          NOT NULL AUTO_INCREMENT,
    fk_funcionario         INT          NOT NULL,
    tipo_contato           VARCHAR(10)  NOT NULL,
    valor_contato          VARCHAR(120) NOT NULL,
    principal              BOOLEAN      NOT NULL DEFAULT 0,
    data_criacao           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_contato_funcionario),
    FOREIGN KEY (fk_funcionario) REFERENCES tb_funcionario(pk_funcionario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CHECK (tipo_contato IN ('telefone','email'))
);

-- Relacionamento aluno-responsavel N:N
CREATE TABLE tb_aluno_responsavel (
    pk_aluno_responsavel INT         NOT NULL AUTO_INCREMENT,
    fk_aluno             INT         NOT NULL,
    fk_responsavel       INT         NOT NULL,
    parentesco           VARCHAR(20) NOT NULL,
    responsavel_legal    BOOLEAN     NOT NULL DEFAULT 0,
    data_criacao         DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_aluno_responsavel),
    UNIQUE (fk_aluno, fk_responsavel),
    FOREIGN KEY (fk_aluno)       REFERENCES tb_aluno(pk_aluno)
        ON DELETE CASCADE  ON UPDATE CASCADE,
    FOREIGN KEY (fk_responsavel) REFERENCES tb_responsavel(pk_responsavel)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (parentesco IN ('Pai','Mae','Avo','Ava','Tio','Tia',
                          'Padrasto','Madrasta','Tutor','Responsavel Legal','Outro'))
);

-- Vinculo familiar entre alunos (ex: irmaos na mesma instituicao)
-- CHECK(fk_aluno_1 <> fk_aluno_2) transferido para trigger (erro 3823)
CREATE TABLE tb_vinculo_familiar (
    pk_vinculo   INT         NOT NULL AUTO_INCREMENT,
    fk_aluno_1   INT         NOT NULL,
    fk_aluno_2   INT         NOT NULL,
    tipo_vinculo VARCHAR(10) NOT NULL DEFAULT 'irmao',
    data_criacao DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_vinculo),
    UNIQUE (fk_aluno_1, fk_aluno_2),
    FOREIGN KEY (fk_aluno_1) REFERENCES tb_aluno(pk_aluno)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (fk_aluno_2) REFERENCES tb_aluno(pk_aluno)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CHECK (tipo_vinculo IN ('irmao','gemeo','primo','outro'))
);

-- Matriculas dos alunos nas turmas
CREATE TABLE tb_matricula (
    pk_matricula       INT         NOT NULL AUTO_INCREMENT,
    fk_aluno           INT         NOT NULL,
    fk_turma           INT         NOT NULL,
    data_matricula     DATE        NOT NULL,
    situacao_matricula VARCHAR(10) NOT NULL DEFAULT 'ativa',
    data_encerramento  DATE,
    data_criacao       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_matricula),
    FOREIGN KEY (fk_aluno) REFERENCES tb_aluno(pk_aluno)
        ON DELETE CASCADE  ON UPDATE CASCADE,
    FOREIGN KEY (fk_turma) REFERENCES tb_turma(pk_turma)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (situacao_matricula IN ('ativa','cancelada','concluida'))
);

-- Lista de espera (max 40 alunos — RN05)
-- CORRECAO: pk_espera → pk_lista_espera (padrao pk_nome_da_tabela)
CREATE TABLE tb_lista_espera (
    pk_lista_espera  INT         NOT NULL AUTO_INCREMENT,
    fk_aluno         INT         NOT NULL,
    fk_turma         INT         NOT NULL,
    data_solicitacao DATE        NOT NULL,
    status_espera    VARCHAR(15) NOT NULL DEFAULT 'aguardando',
    data_chamada     DATE,
    data_criacao     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_lista_espera),
    UNIQUE (fk_aluno, fk_turma),
    FOREIGN KEY (fk_aluno) REFERENCES tb_aluno(pk_aluno)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (fk_turma) REFERENCES tb_turma(pk_turma)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CHECK (status_espera IN ('aguardando','chamado','matriculado','cancelado'))
);


-- Repasses dos programas sociais (fonte de custeio)

CREATE TABLE tb_repasse (
    pk_repasse     INT           NOT NULL AUTO_INCREMENT,
    fk_programa    INT           NOT NULL,
    data_repasse   DATE          NOT NULL,
    valor_repasse  DECIMAL(10,2) NOT NULL,
    mes_referencia CHAR(7)       NOT NULL,
    descricao      VARCHAR(200),
    data_criacao   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_repasse),
    FOREIGN KEY (fk_programa) REFERENCES tb_programa_social(pk_programa)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (valor_repasse > 0),
    CHECK (mes_referencia REGEXP '^[0-9]{4}-[0-9]{2}$')
);




-- Frequencia por dia de aula
-- BI/IA: taxa de presenca e principal feature para previsao de evasao
-- CORRECAO: fk_repasse adicionado — integração direta Academico + Financeiro
CREATE TABLE tb_frequencia (
    pk_frequencia INT      NOT NULL AUTO_INCREMENT,
    fk_matricula  INT      NOT NULL,
    fk_repasse    INT      DEFAULT NULL,
    data_aula     DATE     NOT NULL,
    presente      BOOLEAN  NOT NULL DEFAULT 1,
    motivo_falta  VARCHAR(100),
    data_criacao  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_frequencia),
    UNIQUE (fk_matricula, data_aula),
    FOREIGN KEY (fk_matricula) REFERENCES tb_matricula(pk_matricula)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (fk_repasse)   REFERENCES tb_repasse(pk_repasse)
        ON DELETE SET NULL ON UPDATE CASCADE
);

-- Jornada de trabalho dos funcionarios
CREATE TABLE tb_jornada_trabalho (
    pk_jornada     INT         NOT NULL AUTO_INCREMENT,
    fk_funcionario INT         NOT NULL,
    dia_semana     VARCHAR(15) NOT NULL,
    hora_entrada   TIME        NOT NULL,
    hora_saida     TIME        NOT NULL,
    data_criacao   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_jornada),
    UNIQUE (fk_funcionario, dia_semana),
    FOREIGN KEY (fk_funcionario) REFERENCES tb_funcionario(pk_funcionario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CHECK (dia_semana IN ('Segunda','Terca','Quarta','Quinta','Sexta')),
    CHECK (hora_saida > hora_entrada)
);

-- Registro de ponto dos funcionarios
-- CORRECAO 1: pk_ponto → pk_registro_ponto (padrao pk_nome_da_tabela)
-- CORRECAO 2: hora_entrada TIME NOT NULL (era nullable — inconsistencia com Dicionario)
CREATE TABLE tb_registro_ponto (
    pk_registro_ponto INT      NOT NULL AUTO_INCREMENT,
    fk_funcionario    INT      NOT NULL,
    data_registro     DATE     NOT NULL,
    hora_entrada      TIME     NOT NULL,   -- CORRIGIDO: NOT NULL (entrada sempre obrigatoria)
    hora_saida        TIME,                -- nullable: funcionario ainda nao saiu
    data_criacao      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_registro_ponto),
    UNIQUE (fk_funcionario, data_registro),
    FOREIGN KEY (fk_funcionario) REFERENCES tb_funcionario(pk_funcionario)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- Entidade associativa professor-turma N:N (RN07)
CREATE TABLE tb_professor_turma (
    pk_professor_turma INT      NOT NULL AUTO_INCREMENT,
    fk_funcionario     INT      NOT NULL,
    fk_turma           INT      NOT NULL,
    data_criacao       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_professor_turma),
    UNIQUE (fk_funcionario, fk_turma),
    FOREIGN KEY (fk_funcionario) REFERENCES tb_funcionario(pk_funcionario)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (fk_turma)       REFERENCES tb_turma(pk_turma)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Alertas de risco — integracao Academico + RH
-- BI/IA: tipo_alerta e nivel_risco sao features preditivas de evasao
CREATE TABLE tb_alerta (
    pk_alerta        INT          NOT NULL AUTO_INCREMENT,
    fk_aluno         INT          NOT NULL,
    fk_funcionario   INT          NOT NULL,
    tipo_alerta      VARCHAR(25)  NOT NULL,
    nivel_risco      VARCHAR(10)  NOT NULL DEFAULT 'Medio',
    descricao_alerta VARCHAR(200) NOT NULL,
    data_alerta      DATE         NOT NULL,
    status_alerta    VARCHAR(20)  NOT NULL DEFAULT 'Aberto',
    data_resolucao   DATE,
    data_criacao     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_alerta),
    FOREIGN KEY (fk_aluno)       REFERENCES tb_aluno(pk_aluno)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (fk_funcionario) REFERENCES tb_funcionario(pk_funcionario)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (tipo_alerta   IN ('Frequencia Critica','Vulnerabilidade','Evasao Iminente')),
    CHECK (nivel_risco   IN ('Baixo','Medio','Alto','Critico')),
    CHECK (status_alerta IN ('Aberto','Em Acompanhamento','Resolvido'))
);


-- ================================================================
-- TABELAS DEPENDENTES — Modulo Financeiro
-- ================================================================

-- Repasses dos programas sociais (fonte de custeio)


-- Gastos operacionais vinculados a repasses
CREATE TABLE tb_gasto (
    pk_gasto     INT           NOT NULL AUTO_INCREMENT,
    fk_repasse   INT           NOT NULL,
    fk_categoria INT           NOT NULL,
    data_gasto   DATE          NOT NULL,
    valor_gasto  DECIMAL(10,2) NOT NULL,
    descricao    VARCHAR(200),
    nota_fiscal  VARCHAR(50),
    data_criacao DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_gasto),
    FOREIGN KEY (fk_repasse)   REFERENCES tb_repasse(pk_repasse)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (fk_categoria) REFERENCES tb_categoria_gastos(pk_categoria)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (valor_gasto > 0)
);

-- Faturas a pagar (contas fixas, servicos, etc.)
CREATE TABLE tb_fatura (
    pk_fatura       INT           NOT NULL AUTO_INCREMENT,
    fk_categoria    INT           NOT NULL,
    descricao       VARCHAR(200)  NOT NULL,
    valor_fatura    DECIMAL(10,2) NOT NULL,
    data_vencimento DATE          NOT NULL,
    status_fatura   VARCHAR(10)   NOT NULL DEFAULT 'pendente',
    data_criacao    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_fatura),
    FOREIGN KEY (fk_categoria) REFERENCES tb_categoria_gastos(pk_categoria)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (valor_fatura  > 0),
    CHECK (status_fatura IN ('pendente','paga','vencida'))
);

-- Pagamentos de faturas vinculados a conta bancaria
-- CORRECAO: pk_pgto_fatura → pk_pagamento_fatura (padrao pk_nome_da_tabela)
CREATE TABLE tb_pagamento_fatura (
    pk_pagamento_fatura INT           NOT NULL AUTO_INCREMENT,
    fk_fatura           INT           NOT NULL,
    fk_conta            INT           NOT NULL,
    data_pagamento      DATE          NOT NULL,
    valor_pago          DECIMAL(10,2) NOT NULL,
    data_criacao        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_pagamento_fatura),
    FOREIGN KEY (fk_fatura) REFERENCES tb_fatura(pk_fatura)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (fk_conta)  REFERENCES tb_conta(pk_conta)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (valor_pago > 0)
);

-- Pagamento mensal de funcionarios — integracao RH + Financeiro (RN08)
CREATE TABLE tb_pagamento_funcionario (
    pk_pagamento     INT           NOT NULL AUTO_INCREMENT,
    fk_funcionario   INT           NOT NULL,
    fk_repasse       INT           NOT NULL,
    mes_referencia   CHAR(7)       NOT NULL,
    valor_pago       DECIMAL(10,2) NOT NULL,
    data_pagamento   DATE          NOT NULL,
    status_pagamento VARCHAR(10)   NOT NULL DEFAULT 'pendente',
    data_criacao     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pk_pagamento),
    UNIQUE (fk_funcionario, mes_referencia),
    FOREIGN KEY (fk_funcionario) REFERENCES tb_funcionario(pk_funcionario)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (fk_repasse)     REFERENCES tb_repasse(pk_repasse)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (valor_pago > 0),
    CHECK (mes_referencia    REGEXP '^[0-9]{4}-[0-9]{2}$'),
    CHECK (status_pagamento  IN ('pendente','pago'))
);


-- ================================================================
-- VIEWS
-- ================================================================

-- Alunos com codigo formatado e idade calculada dinamicamente
CREATE VIEW vw_aluno AS
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

-- Saldo disponivel por repasse
CREATE VIEW vw_saldo_repasse AS
SELECT
    r.pk_repasse,
    r.mes_referencia,
    p.nome_programa,
    r.valor_repasse,
    IFNULL((SELECT SUM(g.valor_gasto)
            FROM tb_gasto g
            WHERE g.fk_repasse = r.pk_repasse), 0)                     AS total_gastos,
    IFNULL((SELECT SUM(pf.valor_pago)
            FROM tb_pagamento_funcionario pf
            WHERE pf.fk_repasse = r.pk_repasse), 0)                    AS total_pagamentos,
    r.valor_repasse
        - IFNULL((SELECT SUM(g.valor_gasto)
                  FROM tb_gasto g WHERE g.fk_repasse = r.pk_repasse), 0)
        - IFNULL((SELECT SUM(pf.valor_pago)
                  FROM tb_pagamento_funcionario pf
                  WHERE pf.fk_repasse = r.pk_repasse), 0)              AS saldo_disponivel
FROM tb_repasse r
JOIN tb_programa_social p ON p.pk_programa = r.fk_programa;

-- Ocupacao das turmas em tempo real
CREATE VIEW vw_ocupacao_turmas AS
SELECT
    t.pk_turma,
    t.nome_turma,
    t.turno,
    t.faixa_etaria_inicio,
    t.faixa_etaria_fim,
    t.capacidade_max,
    COUNT(m.pk_matricula)                                               AS alunos_matriculados,
    t.capacidade_max - COUNT(m.pk_matricula)                           AS vagas_disponiveis,
    (SELECT COUNT(*) FROM tb_lista_espera le
     WHERE le.fk_turma = t.pk_turma
       AND le.status_espera = 'aguardando')                            AS alunos_em_espera
FROM tb_turma t
LEFT JOIN tb_matricula m
       ON m.fk_turma = t.pk_turma AND m.situacao_matricula = 'ativa'
GROUP BY t.pk_turma, t.nome_turma, t.turno,
         t.faixa_etaria_inicio, t.faixa_etaria_fim, t.capacidade_max;

-- Total de pessoas na instituicao para controle do limite de 200 (RN03)
CREATE VIEW vw_total_instituicao AS
SELECT
    (SELECT COUNT(*) FROM tb_matricula   WHERE situacao_matricula  = 'ativa') AS total_alunos_ativos,
    (SELECT COUNT(*) FROM tb_funcionario WHERE status_funcionario  = 'ativo') AS total_funcionarios_ativos,
    (SELECT COUNT(*) FROM tb_matricula   WHERE situacao_matricula  = 'ativa')
    + (SELECT COUNT(*) FROM tb_funcionario WHERE status_funcionario = 'ativo') AS total_pessoas;


-- ================================================================
-- TRIGGERS
-- ================================================================

DELIMITER $

-- ------------------------------------------------------------------
-- BLOCO 1: Validacao de CPF (RN10)
-- ------------------------------------------------------------------

CREATE TRIGGER trg_cpf_aluno_insert
BEFORE INSERT ON tb_aluno FOR EACH ROW
BEGIN
    IF fn_validar_cpf(NEW.cpf_aluno) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CPF do aluno invalido.';
    END IF;
END$

CREATE TRIGGER trg_cpf_aluno_update
BEFORE UPDATE ON tb_aluno FOR EACH ROW
BEGIN
    IF fn_validar_cpf(NEW.cpf_aluno) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CPF do aluno invalido.';
    END IF;
END$

CREATE TRIGGER trg_cpf_responsavel_insert
BEFORE INSERT ON tb_responsavel FOR EACH ROW
BEGIN
    IF fn_validar_cpf(NEW.cpf_responsavel) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CPF do responsavel invalido.';
    END IF;
END$

CREATE TRIGGER trg_cpf_responsavel_update
BEFORE UPDATE ON tb_responsavel FOR EACH ROW
BEGIN
    IF fn_validar_cpf(NEW.cpf_responsavel) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CPF do responsavel invalido.';
    END IF;
END$

CREATE TRIGGER trg_cpf_funcionario_insert
BEFORE INSERT ON tb_funcionario FOR EACH ROW
BEGIN
    IF fn_validar_cpf(NEW.cpf_funcionario) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CPF do funcionario invalido.';
    END IF;
END$

CREATE TRIGGER trg_cpf_funcionario_update
BEFORE UPDATE ON tb_funcionario FOR EACH ROW
BEGIN
    IF fn_validar_cpf(NEW.cpf_funcionario) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CPF do funcionario invalido.';
    END IF;
END$

-- ------------------------------------------------------------------
-- BLOCO 2: Validacao de contatos (telefone e e-mail)
-- ------------------------------------------------------------------

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
END$

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
END$

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
END$

-- ------------------------------------------------------------------
-- BLOCO 3: Validacao de vinculo familiar
-- ------------------------------------------------------------------

CREATE TRIGGER trg_vinculo_mesmo_aluno
BEFORE INSERT ON tb_vinculo_familiar FOR EACH ROW
BEGIN
    IF NEW.fk_aluno_1 = NEW.fk_aluno_2 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Um aluno nao pode ter vinculo familiar consigo mesmo.';
    END IF;
END$

-- ------------------------------------------------------------------
-- BLOCO 4: Validacao de idade do aluno (RN01)
-- ------------------------------------------------------------------

CREATE TRIGGER trg_validar_idade_aluno_insert
BEFORE INSERT ON tb_aluno FOR EACH ROW
BEGIN
    DECLARE v_idade INT;
    SET v_idade = TIMESTAMPDIFF(YEAR, NEW.data_nascimento, CURDATE());
    IF v_idade < 8 OR v_idade > 14 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Aluno deve ter entre 8 e 14 anos para ingresso.';
    END IF;
END$

-- Valida SOMENTE quando data_nascimento e alterada (evita bloqueio do sp_encerrar_alunos_14_anos)
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
END$

-- ------------------------------------------------------------------
-- BLOCO 5: Regras de matricula
-- ------------------------------------------------------------------

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
END$

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
        INTO v_faixa_inicio, v_faixa_fim
        FROM tb_turma WHERE pk_turma = NEW.fk_turma;

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
END$

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
END$

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
END$

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
END$

-- RN05 (parte 2): Chamar proximo aluno da fila quando vaga surge
-- CORRECAO: pk_espera → pk_lista_espera nas referencias internas
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
        SELECT pk_lista_espera, fk_aluno        -- CORRECAO: pk_lista_espera
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

            -- Determina turma correta pela idade atual (RN05)
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
                    WHERE  pk_lista_espera = v_espera_id;   -- CORRECAO: pk_lista_espera
                END IF;

            ELSE
                -- Aluno com 14+ anos: cancela fila e encerra participacao (RN06)
                UPDATE tb_lista_espera
                SET    status_espera = 'cancelado',
                       data_chamada  = CURDATE()
                WHERE  pk_lista_espera = v_espera_id;       -- CORRECAO: pk_lista_espera

                UPDATE tb_aluno
                SET    situacao_aluno = 'concluido'
                WHERE  pk_aluno = v_aluno_id;
            END IF;
        END IF;
    END IF;
END$

-- ------------------------------------------------------------------
-- BLOCO 6: Limite da lista de espera — max 40 alunos (RN05)
-- ------------------------------------------------------------------

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
END$

DELIMITER ;


-- ================================================================
-- STORED PROCEDURE + EVENT: Encerramento de alunos com 14 anos (RN06)
-- ================================================================

DELIMITER $

CREATE PROCEDURE sp_encerrar_alunos_14_anos()
BEGIN
    UPDATE tb_matricula m
    JOIN   tb_aluno a ON a.pk_aluno = m.fk_aluno
    SET    m.situacao_matricula = 'concluida',
           m.data_encerramento  = CURDATE()
    WHERE  TIMESTAMPDIFF(YEAR, a.data_nascimento, CURDATE()) >= 14
      AND  m.situacao_matricula = 'ativa';

    UPDATE tb_aluno
    SET    situacao_aluno = 'concluido'
    WHERE  TIMESTAMPDIFF(YEAR, data_nascimento, CURDATE()) >= 14
      AND  situacao_aluno = 'ativo';
END$

DELIMITER ;

SET GLOBAL event_scheduler = ON;

CREATE EVENT IF NOT EXISTS evt_encerrar_alunos_14_anos
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
DO CALL sp_encerrar_alunos_14_anos();


-- ================================================================
-- DADOS INICIAIS
-- ================================================================

INSERT INTO tb_turma
    (nome_turma, turno, faixa_etaria_inicio, faixa_etaria_fim, capacidade_max, ano_letivo, status_turma)
VALUES
    ('Turma 1', 'Manha',  8, 10, 50, 2025, 'ativa'),
    ('Turma 2', 'Manha', 10, 12, 60, 2025, 'ativa'),
    ('Turma 3', 'Tarde', 12, 14, 60, 2025, 'ativa');

INSERT INTO tb_cargo (nome_cargo, descricao_cargo, carga_horaria_padrao) VALUES
    ('Professora',              'Conduz atividades educativas',         30),
    ('Coordenadora',            'Coordenacao pedagogica e gestao',      40),
    ('Assistente Social',       'Acompanhamento social dos alunos',     40),
    ('Auxiliar Administrativo', 'Suporte administrativo e financeiro',  40),
    ('Chefe de Unidade',        'Gestao geral da unidade CCA',          40);

INSERT INTO tb_programa_social (nome_programa, descricao) VALUES
    ('Convenio SMDHC 2025',        'Convenio principal de custeio do CCA'),
    ('Fundo Municipal da Crianca', 'Fundo especifico para CCAs municipais');

INSERT INTO tb_categoria_gastos (nome_categoria, descricao) VALUES
    ('Alimentacao',          'Merenda, lanches e refeicoes'),
    ('Material Pedagogico',  'Cadernos, canetas, tintas, papel'),
    ('Manutencao',           'Reparos e conservacao do espaco'),
    ('Pagamento de Pessoal', 'Salarios e remuneracoes'),
    ('Transporte',           'Locomocao de alunos e funcionarios'),
    ('Contas Fixas',         'Agua, luz, internet, aluguel');

INSERT INTO tb_conta (nome_conta, banco, agencia, numero_conta, saldo) VALUES
    ('Conta Corrente CCA', 'Banco do Brasil', '1234-5', '00012345-6', 0.00);

INSERT INTO tb_funcionario
    (cpf_funcionario, fk_cargo, nome_funcionario, data_admissao, tipo_vinculo, salario, carga_horaria_semanal, status_funcionario)
VALUES
    ('52345678933', 1, 'Luciana Silva',  '2022-02-01', 'CLT',         3200.00, 40, 'ativo'),
    ('98765432029', 1, 'Michelle Souza', '2021-08-01', 'CLT',         3200.00, 40, 'ativo'),
    ('11122233477', 3, 'Thais Oliveira', '2020-03-15', 'Estatutario', 2800.00, 40, 'ativo'),
    ('44455566708', 5, 'Gilmara Costa',  '2019-01-10', 'Estatutario', 4500.00, 40, 'ativo');

INSERT INTO tb_contato_funcionario (fk_funcionario, tipo_contato, valor_contato, principal) VALUES
    (1, 'telefone', '(11) 91111-0001',     1),
    (1, 'email',    'luciana@cca.org.br',  1),
    (2, 'telefone', '(11) 91111-0002',     1),
    (2, 'email',    'michelle@cca.org.br', 1);

INSERT INTO tb_jornada_trabalho (fk_funcionario, dia_semana, hora_entrada, hora_saida) VALUES
    (1,'Segunda','08:00','17:00'),(1,'Terca','08:00','17:00'),(1,'Quarta','08:00','17:00'),
    (1,'Quinta','08:00','17:00'), (1,'Sexta','08:00','17:00'),
    (2,'Segunda','08:00','17:00'),(2,'Terca','08:00','17:00'),(2,'Quarta','08:00','17:00'),
    (2,'Quinta','08:00','17:00'), (2,'Sexta','08:00','17:00');

INSERT INTO tb_professor_turma (fk_funcionario, fk_turma) VALUES
    (1,1),(1,2),(1,3),
    (2,1),(2,2),(2,3);

INSERT INTO tb_responsavel (cpf_responsavel, nome_responsavel) VALUES
    ('10020030169', 'Maria Aparecida Ferreira'),
    ('20030040175', 'Jose Carlos Lima');

INSERT INTO tb_contato_responsavel (fk_responsavel, tipo_contato, valor_contato, principal) VALUES
    (1,'telefone','(11) 91234-5678', 1),
    (1,'email',   'maria@email.com', 1),
    (1,'telefone','(11) 91234-9999', 0),
    (2,'telefone','(11) 92345-6789', 1);

-- Com base em CURDATE() = 2026-04-12:
--   Ana Paula  nascida 2016-05-10 ->  9 anos -> Turma 1 (8-10)  OK
--   Carlos     nascido 2015-11-22 -> 10 anos -> Turma 2 (10-12) OK
--   Beatriz    nascida 2013-03-08 -> 13 anos -> Turma 3 (12-14) OK
--   Pedro      nascido 2013-07-15 -> 12 anos -> Turma 3 (12-14) OK
INSERT INTO tb_aluno
    (nome_aluno, nis_aluno, cpf_aluno, sexo, data_nascimento, raca_cor, situacao_aluno)
VALUES
    ('Ana Paula Ferreira',  '12345678901','51234567083','Feminino',  '2016-05-10','Parda',  'ativo'),
    ('Carlos Eduardo Lima', '98765432100','59876543008','Masculino', '2015-11-22','Preta',  'ativo'),
    ('Beatriz Santos',      '11122233344','51112223088','Feminino',  '2013-03-08','Branca', 'ativo'),
    ('Pedro Henrique Cruz', '55566677788','55556667055','Masculino', '2013-07-15','Parda',  'ativo');

INSERT INTO tb_vinculo_familiar (fk_aluno_1, fk_aluno_2, tipo_vinculo) VALUES (3, 4, 'irmao');

INSERT INTO tb_aluno_responsavel (fk_aluno, fk_responsavel, parentesco, responsavel_legal) VALUES
    (1,1,'Mae',1),
    (2,2,'Pai',1),
    (3,1,'Mae',1),
    (4,1,'Mae',1);

INSERT INTO tb_matricula (fk_aluno, fk_turma, data_matricula, situacao_matricula) VALUES
    (1, 1, '2025-02-01', 'ativa'),
    (2, 2, '2025-02-01', 'ativa'),
    (3, 3, '2025-02-01', 'ativa'),
    (4, 3, '2025-02-01', 'ativa');

-- CORRECAO: fk_repasse incluido nos INSERTs de frequencia
-- (repasse pk=1 = Marco 2025 — inserido a seguir)
INSERT INTO tb_repasse (fk_programa, data_repasse, valor_repasse, mes_referencia, descricao) VALUES
    (1,'2025-03-05',18000.00,'2025-03','Repasse mensal Marco 2025');

INSERT INTO tb_frequencia (fk_matricula, fk_repasse, data_aula, presente, motivo_falta) VALUES
    (1, 1, '2025-03-17', 1, NULL),
    (1, 1, '2025-03-18', 0, 'Consulta medica'),
    (2, 1, '2025-03-17', 1, NULL),
    (3, 1, '2025-03-17', 1, NULL),
    (4, 1, '2025-03-17', 0, NULL);

INSERT INTO tb_gasto (fk_repasse, fk_categoria, data_gasto, valor_gasto, descricao, nota_fiscal) VALUES
    (1, 1,'2025-03-10',1200.00,'Merenda do mes de marco','NF-0012345');

INSERT INTO tb_pagamento_funcionario
    (fk_funcionario, fk_repasse, mes_referencia, valor_pago, data_pagamento, status_pagamento)
VALUES
    (1,1,'2025-03',3200.00,'2025-03-05','pago'),
    (2,1,'2025-03',3200.00,'2025-03-05','pago'),
    (3,1,'2025-03',2800.00,'2025-03-05','pago'),
    (4,1,'2025-03',4500.00,'2025-03-05','pago');

INSERT INTO tb_fatura (fk_categoria, descricao, valor_fatura, data_vencimento, status_fatura) VALUES
    (6,'Conta de luz marco/2025',450.00,'2025-03-15','paga');

INSERT INTO tb_pagamento_fatura (fk_fatura, fk_conta, data_pagamento, valor_pago) VALUES
    (1, 1,'2025-03-14',450.00);

INSERT INTO tb_alerta
    (fk_aluno, fk_funcionario, tipo_alerta, nivel_risco, descricao_alerta, data_alerta, status_alerta)
VALUES
    (4, 3,'Frequencia Critica','Alto',
     'Aluno com multiplas faltas sem justificativa. Responsavel nao atende ligacoes.',
     '2025-03-19','Em Acompanhamento');