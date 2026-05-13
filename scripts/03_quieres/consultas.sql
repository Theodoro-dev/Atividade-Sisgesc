-- ================================================================
-- SisGESC — 03_oltp_consultas.sql
-- Operacoes OLTP: Consultas e Performance
-- ================================================================
-- ESTRUTURA:
--   SECAO 1 — SELECT simples
--   SECAO 2 — SELECT com WHERE e filtros
--   SECAO 3 — SELECT com JOIN
--   SECAO 4 — SELECT com GROUP BY e agregacoes
--   SECAO 5 — SELECT com ORDER BY
--   SECAO 6 — Subqueries simples
--   SECAO 7 — Subqueries correlacionadas
--   SECAO 8 — Subselects com agregacoes avancadas
--   SECAO 9 — INNER JOINs multiplos
-- ================================================================

USE sisgesc_publico_nota;

-- ================================================================
-- SECAO 1 — SELECT SIMPLES
-- Operacoes basicas de leitura de entidades do sistema
-- ================================================================

-- 1.1 Listar todos os alunos com codigo formatado e idade
SELECT * FROM vw_aluno;

-- 1.2 Listar todas as turmas ativas
SELECT pk_turma, nome_turma, turno, faixa_etaria_inicio, faixa_etaria_fim, capacidade_max
FROM   tb_turma
WHERE  status_turma = 'ativa';

-- 1.3 Listar todos os funcionarios com seu cargo
SELECT f.nome_funcionario, c.nome_cargo, f.tipo_vinculo, f.salario, f.status_funcionario
FROM   tb_funcionario f
JOIN   tb_cargo c ON c.pk_cargo = f.fk_cargo;

-- 1.4 Saldo disponivel por repasse
SELECT * FROM vw_saldo_repasse;

-- 1.5 Ocupacao atual das turmas (vagas disponiveis)
SELECT * FROM vw_ocupacao_turmas;

-- 1.6 Total de pessoas na instituicao (limite 200 — RN03)
SELECT * FROM vw_total_instituicao;


-- ================================================================
-- SECAO 2 — SELECT COM WHERE E FILTROS
-- Consultas com condicoes sobre dados operacionais
-- ================================================================

-- 2.1 Alunos ativos do sexo feminino
SELECT nome_aluno, data_nascimento,
       TIMESTAMPDIFF(YEAR, data_nascimento, CURDATE()) AS idade,
       raca_cor
FROM   tb_aluno
WHERE  situacao_aluno = 'ativo'
  AND  sexo = 'Feminino';

-- 2.2 Funcionarios com vinculo CLT e salario acima de R$ 3.000
SELECT nome_funcionario, salario, carga_horaria_semanal, data_admissao
FROM   tb_funcionario
WHERE  tipo_vinculo = 'CLT'
  AND  salario > 3000.00
  AND  status_funcionario = 'ativo';

-- 2.3 Frequencias de um determinado mes com falta justificada
SELECT a.nome_aluno, f.data_aula, f.presente, f.motivo_falta
FROM   tb_frequencia f
JOIN   tb_matricula  m ON m.pk_matricula = f.fk_matricula
JOIN   tb_aluno      a ON a.pk_aluno     = m.fk_aluno
WHERE  f.presente     = 0
  AND  f.motivo_falta IS NOT NULL
  AND  DATE_FORMAT(f.data_aula, '%Y-%m') = '2025-03';

-- 2.4 Matriculas ativas na Turma 3 (faixa 12-14 anos)
SELECT a.nome_aluno, TIMESTAMPDIFF(YEAR, a.data_nascimento, CURDATE()) AS idade,
       m.data_matricula, m.situacao_matricula
FROM   tb_matricula m
JOIN   tb_aluno     a ON a.pk_aluno = m.fk_aluno
WHERE  m.fk_turma          = 3
  AND  m.situacao_matricula = 'ativa';

-- 2.5 Repasses do programa principal com valor acima de R$ 10.000
SELECT r.mes_referencia, ps.nome_programa, r.valor_repasse, r.data_repasse
FROM   tb_repasse r
JOIN   tb_programa_social ps ON ps.pk_programa = r.fk_programa
WHERE  r.valor_repasse > 10000.00;

-- 2.6 Alertas abertos ou em acompanhamento de nivel Alto ou Critico
SELECT a.nome_aluno, al.tipo_alerta, al.nivel_risco,
       al.descricao_alerta, al.data_alerta, al.status_alerta
FROM   tb_alerta  al
JOIN   tb_aluno   a ON a.pk_aluno = al.fk_aluno
WHERE  al.nivel_risco IN ('Alto', 'Critico')
  AND  al.status_alerta <> 'Resolvido'
ORDER BY al.data_alerta DESC;


-- ================================================================
-- SECAO 3 — SELECT COM JOIN
-- Consultas que cruzam multiplas tabelas do sistema
-- ================================================================

-- 3.1 Alunos com seus responsaveis e tipo de parentesco
SELECT a.nome_aluno, r.nome_responsavel, ar.parentesco,
       ar.responsavel_legal,
       cr.valor_contato AS telefone_responsavel
FROM   tb_aluno_responsavel ar
JOIN   tb_aluno       a  ON a.pk_aluno       = ar.fk_aluno
JOIN   tb_responsavel r  ON r.pk_responsavel = ar.fk_responsavel
LEFT JOIN tb_contato_responsavel cr
       ON cr.fk_responsavel = r.pk_responsavel
      AND cr.tipo_contato   = 'telefone'
      AND cr.principal      = 1
ORDER BY a.nome_aluno;

-- 3.2 Alunos matriculados com sua turma e professor principal
SELECT a.nome_aluno,
       t.nome_turma, t.turno,
       TIMESTAMPDIFF(YEAR, a.data_nascimento, CURDATE()) AS idade,
       f.nome_funcionario AS professor
FROM   tb_matricula m
JOIN   tb_aluno     a  ON a.pk_aluno    = m.fk_aluno
JOIN   tb_turma     t  ON t.pk_turma    = m.fk_turma
LEFT JOIN tb_professor_turma pt ON pt.fk_turma = m.fk_turma
LEFT JOIN tb_funcionario     f  ON f.pk_funcionario = pt.fk_funcionario
                                AND f.fk_cargo = (SELECT pk_cargo FROM tb_cargo WHERE nome_cargo = 'Professora' LIMIT 1)
WHERE  m.situacao_matricula = 'ativa'
ORDER BY t.nome_turma, a.nome_aluno;

-- 3.3 Historico de frequencia detalhado por aluno
SELECT a.nome_aluno, t.nome_turma, f.data_aula,
       IF(f.presente, 'Presente', 'Ausente') AS situacao,
       f.motivo_falta
FROM   tb_frequencia f
JOIN   tb_matricula  m ON m.pk_matricula = f.fk_matricula
JOIN   tb_aluno      a ON a.pk_aluno     = m.fk_aluno
JOIN   tb_turma      t ON t.pk_turma     = m.fk_turma
ORDER BY a.nome_aluno, f.data_aula;

-- 3.4 Gastos por categoria e repasse
SELECT ps.nome_programa, r.mes_referencia, cg.nome_categoria,
       g.data_gasto, g.valor_gasto, g.descricao, g.nota_fiscal
FROM   tb_gasto g
JOIN   tb_repasse          r  ON r.pk_repasse  = g.fk_repasse
JOIN   tb_programa_social  ps ON ps.pk_programa = r.fk_programa
JOIN   tb_categoria_gastos cg ON cg.pk_categoria = g.fk_categoria
ORDER BY r.mes_referencia, cg.nome_categoria;

-- 3.5 Professores e turmas em que atuam (RN07)
SELECT f.nome_funcionario, c.nome_cargo,
       GROUP_CONCAT(t.nome_turma ORDER BY t.nome_turma SEPARATOR ', ') AS turmas
FROM   tb_professor_turma pt
JOIN   tb_funcionario f ON f.pk_funcionario = pt.fk_funcionario
JOIN   tb_cargo       c ON c.pk_cargo       = f.fk_cargo
JOIN   tb_turma       t ON t.pk_turma       = pt.fk_turma
GROUP BY f.pk_funcionario, f.nome_funcionario, c.nome_cargo;


-- ================================================================
-- SECAO 4 — SELECT COM GROUP BY E AGREGACOES
-- Consultas de sumarizacao para gestao e relatorios
-- ================================================================

-- 4.1 Taxa de presenca por aluno no mes de marco/2025
SELECT a.nome_aluno,
       COUNT(*)                                                AS total_aulas,
       SUM(f.presente)                                        AS presencas,
       SUM(1 - f.presente)                                    AS ausencias,
       ROUND(SUM(f.presente) * 100.0 / COUNT(*), 1)          AS taxa_presenca_pct,
       IF(ROUND(SUM(f.presente) * 100.0 / COUNT(*), 1) < 75,
          'RISCO DE EVASAO', 'Regular')                       AS situacao_frequencia
FROM   tb_frequencia f
JOIN   tb_matricula  m ON m.pk_matricula = f.fk_matricula
JOIN   tb_aluno      a ON a.pk_aluno     = m.fk_aluno
WHERE  DATE_FORMAT(f.data_aula, '%Y-%m') = '2025-03'
GROUP BY a.pk_aluno, a.nome_aluno
ORDER BY taxa_presenca_pct;

-- 4.2 Total de gastos por categoria no repasse de marco
SELECT cg.nome_categoria,
       COUNT(g.pk_gasto)  AS qtd_lancamentos,
       SUM(g.valor_gasto) AS total_gasto,
       AVG(g.valor_gasto) AS media_por_lancamento
FROM   tb_gasto g
JOIN   tb_categoria_gastos cg ON cg.pk_categoria = g.fk_categoria
GROUP BY cg.pk_categoria, cg.nome_categoria
ORDER BY total_gasto DESC;

-- 4.3 Folha de pagamento por mes — total por vinculo
SELECT pf.mes_referencia,
       f.tipo_vinculo,
       COUNT(pf.pk_pagamento) AS qtd_funcionarios,
       SUM(pf.valor_pago)     AS total_folha
FROM   tb_pagamento_funcionario pf
JOIN   tb_funcionario           f ON f.pk_funcionario = pf.fk_funcionario
GROUP BY pf.mes_referencia, f.tipo_vinculo
ORDER BY pf.mes_referencia, total_folha DESC;

-- 4.4 Quantidade de alunos por turma e situacao
SELECT t.nome_turma, m.situacao_matricula, COUNT(*) AS qtd_alunos
FROM   tb_matricula m
JOIN   tb_turma     t ON t.pk_turma = m.fk_turma
GROUP BY t.pk_turma, t.nome_turma, m.situacao_matricula
ORDER BY t.nome_turma, m.situacao_matricula;

-- 4.5 Alunos com irmao na instituicao (vinculo familiar)
SELECT a1.nome_aluno AS aluno_1, a2.nome_aluno AS aluno_2, vf.tipo_vinculo
FROM   tb_vinculo_familiar vf
JOIN   tb_aluno a1 ON a1.pk_aluno = vf.fk_aluno_1
JOIN   tb_aluno a2 ON a2.pk_aluno = vf.fk_aluno_2;


-- ================================================================
-- SECAO 5 — SELECT COM ORDER BY
-- Consultas com ordenacao relevante para operacoes do sistema
-- ================================================================

-- 5.1 Alunos ordenados por idade (mais novos primeiro) — risco etario
SELECT nome_aluno, data_nascimento,
       TIMESTAMPDIFF(YEAR, data_nascimento, CURDATE()) AS idade,
       situacao_aluno
FROM   tb_aluno
ORDER BY data_nascimento DESC;

-- 5.2 Funcionarios por salario decrescente
SELECT nome_funcionario, fk_cargo, salario, tipo_vinculo, data_admissao
FROM   tb_funcionario
ORDER BY salario DESC, nome_funcionario;

-- 5.3 Faturas ordenadas por vencimento (proximas primeiro)
SELECT f.descricao, cg.nome_categoria, f.valor_fatura,
       f.data_vencimento, f.status_fatura
FROM   tb_fatura f
JOIN   tb_categoria_gastos cg ON cg.pk_categoria = f.fk_categoria
ORDER BY f.data_vencimento;


-- ================================================================
-- SECAO 6 — SUBQUERIES SIMPLES
-- Consultas que usam resultados de outra SELECT como filtro
-- ================================================================

-- 6.1 Alunos matriculados em turmas com capacidade maxima >= 60
SELECT a.nome_aluno, t.nome_turma, t.capacidade_max
FROM   tb_aluno a
JOIN   tb_matricula m ON m.fk_aluno = a.pk_aluno
JOIN   tb_turma     t ON t.pk_turma = m.fk_turma
WHERE  t.pk_turma IN (
    SELECT pk_turma FROM tb_turma WHERE capacidade_max >= 60
);

-- 6.2 Funcionarios que receberam pagamento no mes de marco/2025
SELECT nome_funcionario, salario, tipo_vinculo
FROM   tb_funcionario
WHERE  pk_funcionario IN (
    SELECT fk_funcionario
    FROM   tb_pagamento_funcionario
    WHERE  mes_referencia    = '2025-03'
      AND  status_pagamento  = 'pago'
);

-- 6.3 Alunos que tiveram alguma falta no periodo
SELECT nome_aluno, situacao_aluno
FROM   tb_aluno
WHERE  pk_aluno IN (
    SELECT DISTINCT m.fk_aluno
    FROM   tb_frequencia f
    JOIN   tb_matricula  m ON m.pk_matricula = f.fk_matricula
    WHERE  f.presente = 0
);

-- 6.4 Repasses com valor acima da media dos repasses
SELECT mes_referencia, valor_repasse, descricao
FROM   tb_repasse
WHERE  valor_repasse > (SELECT AVG(valor_repasse) FROM tb_repasse);


-- ================================================================
-- SECAO 7 — SUBQUERIES CORRELACIONADAS
-- Subquery que referencia a query externa — nivel avancado
-- ================================================================

-- 7.1 Alunos com numero de faltas acima da media do seu proprio mes
-- (identifica outliers de frequencia por mes)
WITH faltas_por_aluno_mes AS (
    SELECT
        m.fk_aluno,
        a.nome_aluno,
        DATE_FORMAT(f.data_aula, '%Y-%m') AS mes_referencia,
        COUNT(*)                           AS total_faltas
    FROM   tb_frequencia f
    JOIN   tb_matricula  m ON m.pk_matricula = f.fk_matricula
    JOIN   tb_aluno      a ON a.pk_aluno     = m.fk_aluno
    WHERE  f.presente = 0
    GROUP BY m.fk_aluno, a.nome_aluno, DATE_FORMAT(f.data_aula, '%Y-%m')
),
media_por_mes AS (
    SELECT mes_referencia, AVG(total_faltas) AS media_faltas
    FROM   faltas_por_aluno_mes
    GROUP BY mes_referencia
)
SELECT
    f.nome_aluno,
    f.mes_referencia,
    f.total_faltas AS total_faltas_no_mes
FROM   faltas_por_aluno_mes f
JOIN   media_por_mes        m ON m.mes_referencia = f.mes_referencia
WHERE  f.total_faltas >= m.media_faltas
ORDER BY f.mes_referencia, f.total_faltas DESC
LIMIT 1000;

-- 7.2 Para cada turma, o aluno com maior numero de faltas
-- (subquery correlacionada para ranking por grupo)
SELECT t.nome_turma, a.nome_aluno,
       (SELECT COUNT(*)
        FROM   tb_frequencia f2
        JOIN   tb_matricula  m2 ON m2.pk_matricula = f2.fk_matricula
        WHERE  f2.presente    = 0
          AND  m2.fk_aluno    = a.pk_aluno
          AND  m2.fk_turma    = t.pk_turma
       ) AS total_faltas
FROM   tb_aluno   a
JOIN   tb_matricula m ON m.fk_aluno = a.pk_aluno AND m.situacao_matricula = 'ativa'
JOIN   tb_turma     t ON t.pk_turma = m.fk_turma
ORDER BY t.nome_turma, total_faltas DESC;

-- 7.3 Funcionarios cujo salario e superior ao salario medio do seu cargo
SELECT f.nome_funcionario, c.nome_cargo, f.salario,
       (SELECT AVG(f2.salario)
        FROM   tb_funcionario f2
        WHERE  f2.fk_cargo = f.fk_cargo) AS media_salario_cargo
FROM   tb_funcionario f
JOIN   tb_cargo       c ON c.pk_cargo = f.fk_cargo
WHERE  f.salario > (
    SELECT AVG(f3.salario)
    FROM   tb_funcionario f3
    WHERE  f3.fk_cargo = f.fk_cargo
)
ORDER BY c.nome_cargo, f.salario DESC;

-- 7.4 Responsaveis que possuem mais de um aluno vinculado
SELECT r.nome_responsavel,
       (SELECT COUNT(*)
        FROM   tb_aluno_responsavel ar2
        WHERE  ar2.fk_responsavel = r.pk_responsavel) AS qtd_alunos_vinculados
FROM   tb_responsavel r
WHERE (SELECT COUNT(*)
       FROM   tb_aluno_responsavel ar
       WHERE  ar.fk_responsavel = r.pk_responsavel) > 1;


-- ================================================================
-- SECAO 8 — SUBSELECTS COM AGREGACOES AVANCADAS
-- Consultas de business intelligence sobre dados operacionais
-- ================================================================

-- 8.1 Resumo financeiro do repasse: repasse x gastos x pagamentos x saldo
SELECT
    r.mes_referencia,
    ps.nome_programa,
    r.valor_repasse,
    IFNULL(gastos.total,      0.00) AS total_gastos,
    IFNULL(pagamentos.total,  0.00) AS total_pagamentos,
    r.valor_repasse
        - IFNULL(gastos.total,     0.00)
        - IFNULL(pagamentos.total, 0.00)  AS saldo_disponivel,
    ROUND(
        (IFNULL(gastos.total, 0) + IFNULL(pagamentos.total, 0))
        * 100.0 / r.valor_repasse, 1)    AS pct_utilizado
FROM tb_repasse r
JOIN tb_programa_social ps ON ps.pk_programa = r.fk_programa
LEFT JOIN (
    SELECT fk_repasse, SUM(valor_gasto) AS total
    FROM   tb_gasto
    GROUP BY fk_repasse
) gastos     ON gastos.fk_repasse = r.pk_repasse
LEFT JOIN (
    SELECT fk_repasse, SUM(valor_pago) AS total
    FROM   tb_pagamento_funcionario
    GROUP BY fk_repasse
) pagamentos ON pagamentos.fk_repasse = r.pk_repasse;

-- 8.2 Ranking de presenca dos alunos por turma no mes
SELECT
    t.nome_turma,
    a.nome_aluno,
    presenca.total_aulas,
    presenca.presencas,
    presenca.taxa_pct,
    RANK() OVER (PARTITION BY m.fk_turma ORDER BY presenca.taxa_pct DESC) AS ranking_turma
FROM tb_aluno a
JOIN tb_matricula m ON m.fk_aluno = a.pk_aluno AND m.situacao_matricula = 'ativa'
JOIN tb_turma     t ON t.pk_turma = m.fk_turma
JOIN (
    SELECT fk_matricula,
           COUNT(*)                                              AS total_aulas,
           SUM(presente)                                        AS presencas,
           ROUND(SUM(presente) * 100.0 / COUNT(*), 1)          AS taxa_pct
    FROM   tb_frequencia
    WHERE  DATE_FORMAT(data_aula, '%Y-%m') = '2025-03'
    GROUP BY fk_matricula
) presenca ON presenca.fk_matricula = m.pk_matricula
ORDER BY t.nome_turma, presenca.taxa_pct DESC;

-- 8.3 Custo total por funcionario (salario + beneficios estimados)
-- Demonstra uso de subconsulta agregada em coluna calculada
SELECT
    f.nome_funcionario,
    c.nome_cargo,
    f.salario,
    f.carga_horaria_semanal,
    ROUND(f.salario / f.carga_horaria_semanal, 2) AS custo_hora,
    IFNULL((
        SELECT SUM(pf.valor_pago)
        FROM   tb_pagamento_funcionario pf
        WHERE  pf.fk_funcionario = f.pk_funcionario
    ), 0) AS total_pago_historico
FROM tb_funcionario f
JOIN tb_cargo       c ON c.pk_cargo = f.fk_cargo
WHERE f.status_funcionario = 'ativo'
ORDER BY f.salario DESC;

-- 8.4 Distribuicao racial dos alunos ativos por turma
SELECT
    t.nome_turma,
    a.raca_cor,
    COUNT(*)                              AS qtd,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (PARTITION BY t.pk_turma), 1) AS pct_na_turma
FROM tb_aluno      a
JOIN tb_matricula  m ON m.fk_aluno = a.pk_aluno AND m.situacao_matricula = 'ativa'
JOIN tb_turma      t ON t.pk_turma = m.fk_turma
WHERE a.situacao_aluno = 'ativo'
GROUP BY t.pk_turma, t.nome_turma, a.raca_cor
ORDER BY t.nome_turma, qtd DESC;


-- ================================================================
-- SECAO 9 — INNER JOINs MULTIPLOS
-- Consultas que cruzam 4 ou mais tabelas simultaneamente
-- ================================================================

-- 9.1 Relatorio completo do aluno: dados pessoais + turma + responsavel + presenca
SELECT
    CONCAT('CA', LPAD(a.pk_aluno, 6, '0'))         AS codigo_aluno,
    a.nome_aluno,
    TIMESTAMPDIFF(YEAR, a.data_nascimento, CURDATE()) AS idade,
    a.sexo,
    a.raca_cor,
    t.nome_turma,
    t.turno,
    r.nome_responsavel,
    ar.parentesco,
    IFNULL(cr.valor_contato, 'Nao informado')       AS telefone_responsavel,
    IFNULL(freq.taxa_presenca, 'Sem registros')     AS taxa_presenca_marco
FROM tb_aluno a
JOIN tb_matricula           m  ON m.fk_aluno        = a.pk_aluno
                               AND m.situacao_matricula = 'ativa'
JOIN tb_turma               t  ON t.pk_turma         = m.fk_turma
JOIN tb_aluno_responsavel   ar ON ar.fk_aluno        = a.pk_aluno
                               AND ar.responsavel_legal = 1
JOIN tb_responsavel         r  ON r.pk_responsavel   = ar.fk_responsavel
LEFT JOIN tb_contato_responsavel cr ON cr.fk_responsavel = r.pk_responsavel
                                    AND cr.tipo_contato  = 'telefone'
                                    AND cr.principal     = 1
LEFT JOIN (
    SELECT fk_matricula,
           CONCAT(ROUND(SUM(presente) * 100.0 / COUNT(*), 1), '%') AS taxa_presenca
    FROM   tb_frequencia
    WHERE  DATE_FORMAT(data_aula, '%Y-%m') = '2025-03'
    GROUP BY fk_matricula
) freq ON freq.fk_matricula = m.pk_matricula
ORDER BY t.nome_turma, a.nome_aluno;

-- 9.2 Relatorio financeiro completo: repasse x gasto x categoria x nota fiscal
SELECT
    ps.nome_programa,
    r.mes_referencia,
    r.valor_repasse,
    cg.nome_categoria,
    g.data_gasto,
    g.valor_gasto,
    g.nota_fiscal,
    g.descricao AS descricao_gasto
FROM tb_repasse           r
JOIN tb_programa_social   ps ON ps.pk_programa  = r.fk_programa
JOIN tb_gasto             g  ON g.fk_repasse    = r.pk_repasse
JOIN tb_categoria_gastos  cg ON cg.pk_categoria = g.fk_categoria
ORDER BY r.mes_referencia, cg.nome_categoria;

-- 9.3 Relatorio de folha completa: funcionario + cargo + repasse + pagamento
SELECT
    pf.mes_referencia,
    f.nome_funcionario,
    c.nome_cargo,
    f.tipo_vinculo,
    f.salario              AS salario_base,
    pf.valor_pago          AS valor_pago_mes,
    pf.status_pagamento,
    ps.nome_programa       AS fonte_do_repasse,
    r.valor_repasse        AS total_repasse_do_mes
FROM tb_pagamento_funcionario pf
JOIN tb_funcionario    f  ON f.pk_funcionario = pf.fk_funcionario
JOIN tb_cargo          c  ON c.pk_cargo       = f.fk_cargo
JOIN tb_repasse        r  ON r.pk_repasse     = pf.fk_repasse
JOIN tb_programa_social ps ON ps.pk_programa  = r.fk_programa
ORDER BY pf.mes_referencia, f.nome_funcionario;

-- 9.4 Alertas ativos com dados completos do aluno, turma e profissional responsavel
SELECT
    al.data_alerta,
    al.tipo_alerta,
    al.nivel_risco,
    a.nome_aluno,
    TIMESTAMPDIFF(YEAR, a.data_nascimento, CURDATE()) AS idade_aluno,
    t.nome_turma,
    f.nome_funcionario AS responsavel_alerta,
    c.nome_cargo,
    al.descricao_alerta,
    al.status_alerta
FROM tb_alerta      al
JOIN tb_aluno       a  ON a.pk_aluno       = al.fk_aluno
JOIN tb_matricula   m  ON m.fk_aluno       = a.pk_aluno AND m.situacao_matricula = 'ativa'
JOIN tb_turma       t  ON t.pk_turma       = m.fk_turma
JOIN tb_funcionario f  ON f.pk_funcionario = al.fk_funcionario
JOIN tb_cargo       c  ON c.pk_cargo       = f.fk_cargo
WHERE al.status_alerta <> 'Resolvido'
ORDER BY al.nivel_risco DESC, al.data_alerta;
