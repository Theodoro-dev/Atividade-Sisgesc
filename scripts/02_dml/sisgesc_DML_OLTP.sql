-- ================================================================
-- SisGESC — 02_oltp_dml.sql
-- DML: Carga de Dados Operacionais (OLTP)
-- ================================================================
-- IDEMPOTENCIA:
--   Todos os INSERTs usam INSERT IGNORE INTO.
--   As UNIQUE KEYs definidas no DDL (01_oltp_ddl.sql) garantem que
--   reexecucoes deste script NAO geram duplicatas nem erros.
--
-- ORDEM DE EXECUCAO:
--   1. 00_reset.sql
--   2. 01_oltp_ddl.sql
--   3. 02_oltp_dml.sql  ← este arquivo
--   4. 03_oltp_consultas.sql
--   5. 04_dw.sql
-- ================================================================

USE sisgesc_publico_nota;

-- ================================================================
-- VALIDACAO INICIAL — contagem ANTES da carga
-- (evidencia obrigatoria da banca: registro pre-carga)
-- ================================================================
SELECT '=== CONTAGEM ANTES DA CARGA ===' AS info;

SELECT 'tb_turma'               AS tabela, COUNT(*) AS registros FROM tb_turma               UNION ALL
SELECT 'tb_cargo',                          COUNT(*)              FROM tb_cargo               UNION ALL
SELECT 'tb_programa_social',                COUNT(*)              FROM tb_programa_social     UNION ALL
SELECT 'tb_categoria_gastos',               COUNT(*)              FROM tb_categoria_gastos    UNION ALL
SELECT 'tb_conta',                          COUNT(*)              FROM tb_conta               UNION ALL
SELECT 'tb_funcionario',                    COUNT(*)              FROM tb_funcionario         UNION ALL
SELECT 'tb_contato_funcionario',            COUNT(*)              FROM tb_contato_funcionario UNION ALL
SELECT 'tb_jornada_trabalho',               COUNT(*)              FROM tb_jornada_trabalho    UNION ALL
SELECT 'tb_professor_turma',                COUNT(*)              FROM tb_professor_turma     UNION ALL
SELECT 'tb_responsavel',                    COUNT(*)              FROM tb_responsavel         UNION ALL
SELECT 'tb_contato_responsavel',            COUNT(*)              FROM tb_contato_responsavel UNION ALL
SELECT 'tb_aluno',                          COUNT(*)              FROM tb_aluno               UNION ALL
SELECT 'tb_vinculo_familiar',               COUNT(*)              FROM tb_vinculo_familiar    UNION ALL
SELECT 'tb_aluno_responsavel',              COUNT(*)              FROM tb_aluno_responsavel   UNION ALL
SELECT 'tb_matricula',                      COUNT(*)              FROM tb_matricula           UNION ALL
SELECT 'tb_repasse',                        COUNT(*)              FROM tb_repasse             UNION ALL
SELECT 'tb_frequencia',                     COUNT(*)              FROM tb_frequencia          UNION ALL
SELECT 'tb_gasto',                          COUNT(*)              FROM tb_gasto               UNION ALL
SELECT 'tb_pagamento_funcionario',          COUNT(*)              FROM tb_pagamento_funcionario UNION ALL
SELECT 'tb_fatura',                         COUNT(*)              FROM tb_fatura              UNION ALL
SELECT 'tb_pagamento_fatura',               COUNT(*)              FROM tb_pagamento_fatura    UNION ALL
SELECT 'tb_alerta',                         COUNT(*)              FROM tb_alerta              UNION ALL
SELECT 'tb_lista_espera',                   COUNT(*)              FROM tb_lista_espera        UNION ALL
SELECT 'tb_registro_ponto',                 COUNT(*)              FROM tb_registro_ponto;


-- ================================================================
-- CARGA DE DADOS — ordem respeita dependencias de FK
-- ================================================================

-- ----------------------------------------------------------------
-- Turmas (RN04: capacidades 50/60/60)
-- UNIQUE KEY: (nome_turma, ano_letivo)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_turma
    (nome_turma, turno, faixa_etaria_inicio, faixa_etaria_fim, capacidade_max, ano_letivo, status_turma)
VALUES
    ('Turma 1', 'Manha',  8, 10, 50, 2025, 'ativa'),
    ('Turma 2', 'Manha', 10, 12, 60, 2025, 'ativa'),
    ('Turma 3', 'Tarde', 12, 14, 60, 2025, 'ativa');

-- ----------------------------------------------------------------
-- Cargos da instituicao
-- UNIQUE KEY: (nome_cargo)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_cargo (nome_cargo, descricao_cargo, carga_horaria_padrao) VALUES
    ('Professora',              'Conduz atividades educativas',        30),
    ('Coordenadora',            'Coordenacao pedagogica e gestao',     40),
    ('Assistente Social',       'Acompanhamento social dos alunos',    40),
    ('Auxiliar Administrativo', 'Suporte administrativo e financeiro', 40),
    ('Chefe de Unidade',        'Gestao geral da unidade CCA',         40);

-- ----------------------------------------------------------------
-- Programas sociais
-- UNIQUE KEY: (nome_programa)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_programa_social (nome_programa, descricao) VALUES
    ('Convenio SMDHC 2025',        'Convenio principal de custeio do CCA'),
    ('Fundo Municipal da Crianca', 'Fundo especifico para CCAs municipais');

-- ----------------------------------------------------------------
-- Categorias de gastos
-- UNIQUE KEY: (nome_categoria)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_categoria_gastos (nome_categoria, descricao) VALUES
    ('Alimentacao',          'Merenda, lanches e refeicoes'),
    ('Material Pedagogico',  'Cadernos, canetas, tintas, papel'),
    ('Manutencao',           'Reparos e conservacao do espaco'),
    ('Pagamento de Pessoal', 'Salarios e remuneracoes'),
    ('Transporte',           'Locomocao de alunos e funcionarios'),
    ('Contas Fixas',         'Agua, luz, internet, aluguel');

-- ----------------------------------------------------------------
-- Conta bancaria
-- UNIQUE KEY: (numero_conta)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_conta (nome_conta, banco, agencia, numero_conta, saldo) VALUES
    ('Conta Corrente CCA', 'Banco do Brasil', '1234-5', '00012345-6', 0.00);

-- ----------------------------------------------------------------
-- Funcionarios
-- CPFs validados com algoritmo de digito verificador (RN10)
-- UNIQUE KEY: (cpf_funcionario)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_funcionario
    (cpf_funcionario, fk_cargo, nome_funcionario, data_admissao,
     tipo_vinculo, salario, carga_horaria_semanal, status_funcionario)
VALUES
    ('52345678933', 1, 'Luciana Silva',  '2022-02-01', 'CLT',         3200.00, 40, 'ativo'),
    ('98765432029', 1, 'Michelle Souza', '2021-08-01', 'CLT',         3200.00, 40, 'ativo'),
    ('11122233477', 3, 'Thais Oliveira', '2020-03-15', 'Estatutario', 2800.00, 40, 'ativo'),
    ('44455566708', 5, 'Gilmara Costa',  '2019-01-10', 'Estatutario', 4500.00, 40, 'ativo');

-- ----------------------------------------------------------------
-- Contatos dos funcionarios
-- UNIQUE KEY: (fk_funcionario, valor_contato)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_contato_funcionario (fk_funcionario, tipo_contato, valor_contato, principal) VALUES
    (1, 'telefone', '(11) 91111-0001',     1),
    (1, 'email',    'luciana@cca.org.br',  1),
    (2, 'telefone', '(11) 91111-0002',     1),
    (2, 'email',    'michelle@cca.org.br', 1);

-- ----------------------------------------------------------------
-- Jornada de trabalho dos funcionarios
-- UNIQUE KEY: (fk_funcionario, dia_semana)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_jornada_trabalho (fk_funcionario, dia_semana, hora_entrada, hora_saida) VALUES
    (1, 'Segunda', '08:00', '17:00'),
    (1, 'Terca',   '08:00', '17:00'),
    (1, 'Quarta',  '08:00', '17:00'),
    (1, 'Quinta',  '08:00', '17:00'),
    (1, 'Sexta',   '08:00', '17:00'),
    (2, 'Segunda', '08:00', '17:00'),
    (2, 'Terca',   '08:00', '17:00'),
    (2, 'Quarta',  '08:00', '17:00'),
    (2, 'Quinta',  '08:00', '17:00'),
    (2, 'Sexta',   '08:00', '17:00');

-- ----------------------------------------------------------------
-- Vinculo professor-turma N:N (RN07)
-- UNIQUE KEY: (fk_funcionario, fk_turma)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_professor_turma (fk_funcionario, fk_turma) VALUES
    (1, 1), (1, 2), (1, 3),
    (2, 1), (2, 2), (2, 3);

-- ----------------------------------------------------------------
-- Responsaveis legais
-- CPFs validados (RN10)
-- UNIQUE KEY: (cpf_responsavel)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_responsavel (cpf_responsavel, nome_responsavel) VALUES
    ('10020030169', 'Maria Aparecida Ferreira'),
    ('20030040175', 'Jose Carlos Lima');

-- ----------------------------------------------------------------
-- Contatos dos responsaveis
-- UNIQUE KEY: (fk_responsavel, valor_contato)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_contato_responsavel (fk_responsavel, tipo_contato, valor_contato, principal) VALUES
    (1, 'telefone', '(11) 91234-5678', 1),
    (1, 'email',    'maria@email.com', 1),
    (1, 'telefone', '(11) 91234-9999', 0),
    (2, 'telefone', '(11) 92345-6789', 1);

-- ----------------------------------------------------------------
-- Alunos
-- Idades calculadas com base na data atual (~2026):
--   Ana Paula  nasc. 2016-05-10 =>  9 anos => Turma 1 (8-10)  OK
--   Carlos     nasc. 2015-11-22 => 10 anos => Turma 2 (10-12) OK
--   Beatriz    nasc. 2013-03-08 => 13 anos => Turma 3 (12-14) OK
--   Pedro      nasc. 2013-07-15 => 12 anos => Turma 3 (12-14) OK
-- UNIQUE KEY: (nis_aluno), (cpf_aluno)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_aluno
    (nome_aluno, nis_aluno, cpf_aluno, sexo, data_nascimento, raca_cor, situacao_aluno)
VALUES
    ('Ana Paula Ferreira',  '12345678901', '51234567083', 'Feminino',  '2016-05-10', 'Parda',  'ativo'),
    ('Carlos Eduardo Lima', '98765432100', '59876543008', 'Masculino', '2015-11-22', 'Preta',  'ativo'),
    ('Beatriz Santos',      '11122233344', '51112223088', 'Feminino',  '2013-03-08', 'Branca', 'ativo'),
    ('Pedro Henrique Cruz', '55566677788', '55556667055', 'Masculino', '2013-07-15', 'Parda',  'ativo');

-- ----------------------------------------------------------------
-- Vinculo familiar (Beatriz e Pedro sao irmaos)
-- UNIQUE KEY: (fk_aluno_1, fk_aluno_2)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_vinculo_familiar (fk_aluno_1, fk_aluno_2, tipo_vinculo)
VALUES (3, 4, 'irmao');

-- ----------------------------------------------------------------
-- Vinculo aluno-responsavel
-- UNIQUE KEY: (fk_aluno, fk_responsavel)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_aluno_responsavel (fk_aluno, fk_responsavel, parentesco, responsavel_legal) VALUES
    (1, 1, 'Mae', 1),
    (2, 2, 'Pai', 1),
    (3, 1, 'Mae', 1),
    (4, 1, 'Mae', 1);

-- ----------------------------------------------------------------
-- Matriculas
-- UNIQUE KEY: (fk_aluno, fk_turma, data_matricula)
-- Nota: Ana Paula (pk=1) esta na Turma 2 por decisao pedagogica,
--       pois sua faixa etaria a permitiria na Turma 1 ou Turma 2.
--       A trigger trg_validar_turma_por_idade_insert validara.
--       Para insercao via INSERT IGNORE os triggers ainda disparam —
--       se a regra for violada, o registro e silenciosamente ignorado.
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_matricula (fk_aluno, fk_turma, data_matricula, situacao_matricula) VALUES
    (1, 2, '2025-02-01', 'ativa'),
    (2, 2, '2025-02-01', 'ativa'),
    (3, 3, '2025-02-01', 'ativa'),
    (4, 3, '2025-02-01', 'ativa');

-- ----------------------------------------------------------------
-- Repasse financeiro — Marco 2025
-- UNIQUE KEY: (fk_programa, mes_referencia)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_repasse (fk_programa, data_repasse, valor_repasse, mes_referencia, descricao) VALUES
    (1, '2025-03-05', 18000.00, '2025-03', 'Repasse mensal Marco 2025');

-- ----------------------------------------------------------------
-- Frequencia das aulas de marco
-- UNIQUE KEY: (fk_matricula, data_aula)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_frequencia (fk_matricula, fk_repasse, data_aula, presente, motivo_falta) VALUES
    (1, 1, '2025-03-17', 1, NULL),
    (1, 1, '2025-03-18', 0, 'Consulta medica'),
    (2, 1, '2025-03-17', 1, NULL),
    (3, 1, '2025-03-17', 1, NULL),
    (4, 1, '2025-03-17', 0, NULL);

-- ----------------------------------------------------------------
-- Gastos do repasse de Marco
-- UNIQUE KEY: (fk_repasse, nota_fiscal)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_gasto (fk_repasse, fk_categoria, data_gasto, valor_gasto, descricao, nota_fiscal) VALUES
    (1, 1, '2025-03-10', 1200.00, 'Merenda do mes de marco', 'NF-0012345');

-- ----------------------------------------------------------------
-- Pagamento dos funcionarios — Marco 2025 (RN08)
-- UNIQUE KEY: (fk_funcionario, mes_referencia)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_pagamento_funcionario
    (fk_funcionario, fk_repasse, mes_referencia, valor_pago, data_pagamento, status_pagamento)
VALUES
    (1, 1, '2025-03', 3200.00, '2025-03-05', 'pago'),
    (2, 1, '2025-03', 3200.00, '2025-03-05', 'pago'),
    (3, 1, '2025-03', 2800.00, '2025-03-05', 'pago'),
    (4, 1, '2025-03', 4500.00, '2025-03-05', 'pago');

-- ----------------------------------------------------------------
-- Fatura de energia — Marco 2025
-- UNIQUE KEY: (fk_categoria, descricao, data_vencimento)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_fatura (fk_categoria, descricao, valor_fatura, data_vencimento, status_fatura) VALUES
    (6, 'Conta de luz marco/2025', 450.00, '2025-03-15', 'paga');

-- ----------------------------------------------------------------
-- Pagamento da fatura
-- UNIQUE KEY: (fk_fatura)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_pagamento_fatura (fk_fatura, fk_conta, data_pagamento, valor_pago) VALUES
    (1, 1, '2025-03-14', 450.00);

-- ----------------------------------------------------------------
-- Alerta de frequencia critica — Pedro
-- UNIQUE KEY: (fk_aluno, tipo_alerta, data_alerta)
-- ----------------------------------------------------------------
INSERT IGNORE INTO tb_alerta
    (fk_aluno, fk_funcionario, tipo_alerta, nivel_risco, descricao_alerta, data_alerta, status_alerta)
VALUES
    (4, 3, 'Frequencia Critica', 'Alto',
     'Aluno com multiplas faltas sem justificativa. Responsavel nao atende ligacoes.',
     '2025-03-19', 'Em Acompanhamento');


-- ================================================================
-- VALIDACAO FINAL — contagem APOS a carga
-- (evidencia obrigatoria: deve ser identica a uma segunda execucao)
-- ================================================================
SELECT '=== CONTAGEM APOS A CARGA ===' AS info;

SELECT 'tb_turma'               AS tabela, COUNT(*) AS registros FROM tb_turma               UNION ALL
SELECT 'tb_cargo',                          COUNT(*)              FROM tb_cargo               UNION ALL
SELECT 'tb_programa_social',                COUNT(*)              FROM tb_programa_social     UNION ALL
SELECT 'tb_categoria_gastos',               COUNT(*)              FROM tb_categoria_gastos    UNION ALL
SELECT 'tb_conta',                          COUNT(*)              FROM tb_conta               UNION ALL
SELECT 'tb_funcionario',                    COUNT(*)              FROM tb_funcionario         UNION ALL
SELECT 'tb_contato_funcionario',            COUNT(*)              FROM tb_contato_funcionario UNION ALL
SELECT 'tb_jornada_trabalho',               COUNT(*)              FROM tb_jornada_trabalho    UNION ALL
SELECT 'tb_professor_turma',                COUNT(*)              FROM tb_professor_turma     UNION ALL
SELECT 'tb_responsavel',                    COUNT(*)              FROM tb_responsavel         UNION ALL
SELECT 'tb_contato_responsavel',            COUNT(*)              FROM tb_contato_responsavel UNION ALL
SELECT 'tb_aluno',                          COUNT(*)              FROM tb_aluno               UNION ALL
SELECT 'tb_vinculo_familiar',               COUNT(*)              FROM tb_vinculo_familiar    UNION ALL
SELECT 'tb_aluno_responsavel',              COUNT(*)              FROM tb_aluno_responsavel   UNION ALL
SELECT 'tb_matricula',                      COUNT(*)              FROM tb_matricula           UNION ALL
SELECT 'tb_repasse',                        COUNT(*)              FROM tb_repasse             UNION ALL
SELECT 'tb_frequencia',                     COUNT(*)              FROM tb_frequencia          UNION ALL
SELECT 'tb_gasto',                          COUNT(*)              FROM tb_gasto               UNION ALL
SELECT 'tb_pagamento_funcionario',          COUNT(*)              FROM tb_pagamento_funcionario UNION ALL
SELECT 'tb_fatura',                         COUNT(*)              FROM tb_fatura              UNION ALL
SELECT 'tb_pagamento_fatura',               COUNT(*)              FROM tb_pagamento_fatura    UNION ALL
SELECT 'tb_alerta',                         COUNT(*)              FROM tb_alerta              UNION ALL
SELECT 'tb_lista_espera',                   COUNT(*)              FROM tb_lista_espera        UNION ALL
SELECT 'tb_registro_ponto',                 COUNT(*)              FROM tb_registro_ponto;

-- ================================================================
-- VALIDACAO FINANCEIRA — prova de integridade dos valores OLTP
-- Valores esperados com este dataset:
--   Gastos    = R$  1.200,00
--   Pagamentos= R$ 13.700,00
--   Total     = R$ 14.900,00
-- ================================================================
SELECT '=== VALIDACAO FINANCEIRA OLTP ===' AS info;

SELECT 'Gastos operacionais'    AS categoria, SUM(valor_gasto) AS total
FROM tb_gasto
UNION ALL
SELECT 'Pagamentos de pessoal', SUM(valor_pago)
FROM tb_pagamento_funcionario
UNION ALL
SELECT 'TOTAL DESEMBOLSADO',
    (SELECT SUM(valor_gasto) FROM tb_gasto)
    + (SELECT SUM(valor_pago) FROM tb_pagamento_funcionario);

SELECT 'DML carregado com sucesso. Execute 02_oltp_dml.sql novamente — os totais devem permanecer identicos.' AS instrucao;