# 📋 SisGESC — Sistema de Gestão do CCA Bom Jesus do Cangaíba
> Repositório: `sistema-gestao-sisgesc` | Projeto de Banco de Dados — UNICID
---

## 🗂️ Visão Geral do Projeto
Sistema de banco de dados desenvolvido para gerenciar as operações do **CCA Bom Jesus do Cangaíba**, organizado em quatro módulos integrados: **Acadêmico**, **RH** e **Financeiro**, com foco em integridade referencial, rastreabilidade dos dados e suporte a análises de **BI/IA para previsão de evasão escolar**.

---

## 📅 Histórico de Iterações

---

### ✅ Iteração 1 — Levantamento de Requisitos e Arquitetura
**Objetivo:** Mapear as necessidades da instituição e definir os módulos do sistema.

**Entregas:**
- Definição dos 3 módulos: Acadêmico · RH · Financeiro
- Identificação das entidades principais por módulo
- Decisões técnicas: `DECIMAL` para campos financeiros, prefixos `pk_` / `fk_` / `tb_`, snake_case

| Módulo | Responsabilidade |
|---|---|
| 📚 Acadêmico | Alunos, responsáveis, turmas, matrículas, frequência, lista de espera |
| 👥 RH | Funcionários, cargos, contatos, jornadas, ponto |
| 💰 Financeiro | Programas sociais, repasses, gastos, faturas, pagamentos |

---

### ✅ Iteração 2 — Modelagem e Script DDL
**Objetivo:** Criar o esquema completo com **24 tabelas** em MySQL, implementando todas as regras de negócio.

**Tabelas por módulo:**

| Módulo | Tabelas |
|---|---|
| 📚 Acadêmico | `tb_aluno`, `tb_responsavel`, `tb_aluno_responsavel`, `tb_vinculo_familiar`, `tb_turma`, `tb_matricula`, `tb_lista_espera`, `tb_frequencia` |
| 👥 RH | `tb_funcionario`, `tb_cargo`, `tb_contato_funcionario`, `tb_contato_responsavel`, `tb_jornada_trabalho`, `tb_registro_ponto`, `tb_professor_turma` |
| 💰 Financeiro | `tb_programa_social`, `tb_repasse`, `tb_categoria_gastos`, `tb_conta`, `tb_gasto`, `tb_fatura`, `tb_pagamento_fatura`, `tb_pagamento_funcionario` |
| 🔗 Cross-módulo | `tb_alerta` |

---

### ✅ Iteração 3 — Padronização (Regra de Ouro)
**Objetivo:** Definir convenções de nomenclatura para todo o esquema.

| Elemento | Padrão | Exemplo |
|---|---|---|
| Tabelas | `tb_` + singular + snake_case | `tb_aluno`, `tb_pagamento_fatura` |
| Chave Primária | `pk_` + nome da entidade | `pk_aluno`, `pk_repasse` |
| Chave Estrangeira | `fk_` + referência | `fk_turma`, `fk_funcionario` |
| Tipos monetários | `DECIMAL(10,2)` | `valor_repasse`, `valor_pago` |
| Datas | `DATE` ou `DATETIME` | `data_matricula`, `data_criacao` |
| Mês de referência | `CHAR(7)` com formato `YYYY-MM` | `mes_referencia` |
| Auditoria | `data_criacao` | Em todas as tabelas |

---

### ✅ Iteração 4 — Diagramas ER
**Objetivo:** Representar visualmente todas as entidades e relacionamentos do sistema.

**Arquivos gerados:**
- `Deerdbdiagram.pdf` — Diagrama ER completo
- `DEERMYSQL.pdf` — Diagrama gerado via MySQL Workbench

---

### ✅ Iteração 5 — Regras de Negócio e Objetos Programáticos
**Objetivo:** Implementar as 10 regras de negócio via triggers, functions, procedure e event scheduler.

**Regras de Negócio implementadas:**

| Código | Regra | Implementação |
|---|---|---|
| RN01 | Aluno deve ter entre 8 e 14 anos | `trg_validar_idade_aluno_insert/update` |
| RN02 | Um aluno só pode ter UMA matrícula ativa por vez | `trg_matricula_unica_insert` |
| RN03 | Limite total de 200 pessoas (alunos ativos + funcionários ativos) | `trg_limite_instituicao` + `vw_total_instituicao` |
| RN04 | Capacidade por turma: Turma 1=50, Turma 2=60, Turma 3=60 | `trg_capacidade_turma_insert` |
| RN05 | Lista de espera máx. 40; inserção direta bloqueada com fila ativa; prioridade LIFO; turma atribuída pela idade atual | `trg_bloquear_insercao_com_fila` + `trg_chamar_lista_espera` + `trg_limite_lista_espera` |
| RN06 | Aluno com 14 anos completos é encerrado automaticamente | `sp_encerrar_alunos_14_anos` + `evt_encerrar_alunos_14_anos` (diário) |
| RN07 | Professor pode atuar em múltiplas turmas (N:N) | `tb_professor_turma` |
| RN08 | Pagamento de funcionário vinculado ao repasse do programa social | `tb_pagamento_funcionario.fk_repasse` |
| RN09 | Idade do aluno deve ser compatível com a faixa etária da turma | `trg_validar_turma_por_idade_insert` |
| RN10 | CPF validado com algoritmo de dígito verificador | `fn_validar_cpf` + triggers de CPF |

**Objetos criados no banco:**

| Tipo | Objetos |
|---|---|
| Functions | `fn_validar_cpf`, `fn_validar_email`, `fn_validar_telefone` |
| Views | `vw_aluno`, `vw_saldo_repasse`, `vw_ocupacao_turmas`, `vw_total_instituicao` |
| Triggers | `trg_cpf_*` (6), `trg_contato_*` (3), `trg_vinculo_mesmo_aluno`, `trg_validar_idade_*` (2), `trg_matricula_unica_insert`, `trg_validar_turma_por_idade_insert`, `trg_capacidade_turma_insert`, `trg_limite_instituicao`, `trg_bloquear_insercao_com_fila`, `trg_chamar_lista_espera`, `trg_limite_lista_espera` |
| Stored Procedure | `sp_encerrar_alunos_14_anos` |
| Event | `evt_encerrar_alunos_14_anos` (execução diária via `event_scheduler`) |

---

### ✅ Iteração 6 — Carga de Dados (DML) e Idempotência
**Objetivo:** Popular o banco com dados operacionais reais garantindo reexecução segura.

**Destaques:**
- Todos os `INSERT`s utilizam `INSERT IGNORE INTO`, garantindo idempotência com as `UNIQUE KEY`s do DDL
- Validação de contagem antes e após a carga (evidência obrigatória para banca)
- Dados carregados para as 24 tabelas, respeitando a ordem de dependências de FK

---

### 🔮 Campos para BI/IA — Previsão de Evasão
O esquema foi projetado com campos específicos para alimentar modelos preditivos:

| Campo | Tabela | Uso Analítico |
|---|---|---|
| `presente` | `tb_frequencia` | Taxa de presença por aluno/turma |
| `fk_repasse` | `tb_frequencia` | Vínculo direto Acadêmico–Financeiro |
| `tipo_alerta` | `tb_alerta` | Sinalização de risco de evasão |
| `nivel_risco` | `tb_alerta` | Grau de urgência do alerta |
| `situacao_aluno` | `tb_aluno` | Status atual do aluno |
| `situacao_matricula` | `tb_matricula` | Histórico de cancelamentos |
| `data_nascimento` | `tb_aluno` | Cálculo dinâmico de faixa etária |
| `data_solicitacao` | `tb_lista_espera` | Tempo de espera na fila |

---

## 🗃️ Estrutura do Repositório

```
sistema-gestao-sisgesc/
│
├── README.md
├── sisgesc_OLTP.sql              # Script DDL — estrutura completa (24 tabelas, triggers, views, functions, procedure, event)
├── sisgesc_DML_OLTP.sql          # Script DML — carga de dados operacionais (idempotente)
├── sisgec_OLTP_DML_OLTP.sql      # Script unificado DDL + DML
├── Deerdbdiagram.pdf             # Diagrama ER (dbdiagram.io)
└── DEERMYSQL.pdf                 # Diagrama ER (MySQL Workbench)
```

**Ordem de execução recomendada:**
```
00_reset.sql → 01_oltp_ddl.sql → 02_oltp_dml.sql → 03_oltp_consultas.sql → 04_dw.sql
```

---

## 🛠️ Tecnologias
- MySQL 8.0
- MySQL Workbench
- dbdiagram.io

---

## 👥 Equipe

| Nome |
|---|
| Ana Clara Gregório dos Santos |
| Agatha Ribeiro |
| Bruno Oliveira Theodoro |
| Cauê Porto de Andrade |
| Dandhara Fernandes de Campos Lima |
| Duquesnio Daniel Bandessa|
| Gabriela Dias Santos Barros |
| Kauan Alba Elias |
| Rayssa dos Santos |
| Yasmim Bueno Miranda da Silva |

---

## 🏛️ Instituição
Projeto Extensionista — **UNIVERSIDADE CIDADE DE SÃO PAULO (UNICID)** · Disciplina: Banco de Dados · 2026
