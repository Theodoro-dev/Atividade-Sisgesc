
---

# 📋 SisGESC — Sistema de Gestão do CCA Bom Jesus do Cangaíba

> **Repositório:** `sistema-gestao-sisgesc` | Projeto de Banco de Dados — UNICID

---

## 🗂️ Visão Geral do Projeto

Sistema de banco de dados desenvolvido para gerenciar as operações do **CCA Bom Jesus do Cangaíba**, organizado em três módulos integrados: **Acadêmico**, **RH** e **Financeiro**. O projeto enfatiza integridade referencial, rastreabilidade dos dados e suporte a análises de **BI/IA** para previsão de evasão escolar.

---

## 🎯 Objetivos do Sistema

- Centralizar a gestão administrativa do CCA
- Garantir integridade e consistência dos dados
- Automatizar regras de negócio via SQL (triggers, procedures, eventos)
- Facilitar análises gerenciais e estratégicas
- Preparar dados para Business Intelligence e Inteligência Artificial
- Permitir rastreabilidade e auditoria das operações

---

## 🧩 Módulos do Sistema

| Módulo          | Responsabilidade                                   |
| --------------- | -------------------------------------------------- |
| 📚 Acadêmico    | Gestão de alunos, matrículas, frequência e turmas  |
| 👥 RH           | Controle de funcionários, cargos, jornadas e ponto |
| 💰 Financeiro   | Repasses, gastos, pagamentos e contas              |
| 🔗 Cross-módulo | Alertas inteligentes e integração entre módulos    |

---

## 📅 Histórico de Iterações

### Iteração 1 — Levantamento de Requisitos
- Definição dos módulos e entidades principais
- Arquitetura OLTP + OLAP

### Iteração 2 — Modelagem e Script DDL
- 24 tabelas implementadas em MySQL

| Módulo          | Tabelas                                                                                                                         |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| 📚 Acadêmico    | `tb_aluno`, `tb_responsavel`, `tb_aluno_responsavel`, `tb_vinculo_familiar`, `tb_turma`, `tb_matricula`, `tb_lista_espera`, `tb_frequencia` |
| 👥 RH           | `tb_funcionario`, `tb_cargo`, `tb_contato_funcionario`, `tb_contato_responsavel`, `tb_jornada_trabalho`, `tb_registro_ponto`, `tb_professor_turma` |
| 💰 Financeiro   | `tb_programa_social`, `tb_repasse`, `tb_categoria_gastos`, `tb_conta`, `tb_gasto`, `tb_fatura`, `tb_pagamento_fatura`, `tb_pagamento_funcionario` |
| 🔗 Cross-módulo | `tb_alerta`                                                                                                                     |

### Iteração 3 — Padronização
- Prefixo `tb_` + snake_case, chaves `pk_*` e `fk_*`
- Tipos: `DECIMAL(10,2)` para monetário, `DATE`/`DATETIME`, coluna `data_criacao` para auditoria

### Iteração 4 — Diagramas ER
- `Deerdbdiagram.pdf` e `DEERMYSQL.pdf`

### Iteração 5 — Regras de Negócio

| Código | Regra                               | Implementação       |
| ------ | ----------------------------------- | ------------------- |
| RN01   | Aluno entre 8 e 14 anos             | Triggers            |
| RN02   | Apenas uma matrícula ativa          | Trigger             |
| RN03   | Limite de 200 pessoas               | Trigger + View      |
| RN04   | Capacidade máxima por turma         | Trigger             |
| RN05   | Controle da lista de espera         | Triggers            |
| RN06   | Encerramento automático aos 14 anos | Procedure + Event   |
| RN07   | Professor em múltiplas turmas       | Tabela N:N          |
| RN08   | Pagamento vinculado ao repasse      | FK                  |
| RN09   | Compatibilidade idade/turma         | Trigger             |
| RN10   | Validação de CPF                    | Function + Triggers |

### Iteração 6 — DML e Idempotência
- Uso de `INSERT IGNORE`, execução segura e reexecutável, ordem correta de dependências

---

## 🔮 Preparação para BI e IA

| Campo                | Tabela          | Uso                  |
| -------------------- | --------------- | -------------------- |
| `presente`           | `tb_frequencia` | Taxa de presença     |
| `tipo_alerta`        | `tb_alerta`     | Sinalização de risco |
| `nivel_risco`        | `tb_alerta`     | Grau de criticidade  |
| `situacao_aluno`     | `tb_aluno`      | Status do aluno      |
| `situacao_matricula` | `tb_matricula`  | Histórico acadêmico  |

---

## 🗃️ Estrutura do Repositório

```text
📁 Atividade-Sisgesc/
├── 📁 docs/                 → Diagramas ER
├── 📁 scripts/
│   ├── 01_ddl/              → sisgesc_OLTP.sql
│   ├── 02_dml/              → sisgesc_DML_OLTP.sql
│   ├── 03_queries/          → consultas.sql
│   ├── 04_etl_dw/           → sisgesc_OLAP.sql
│   └── 05_reset/            → reset.sql
├── README.md
└── Sisgesc_run_all.sql      ← Script único de instalação
```

---

## 🚀 Como Executar o Projeto (Script Único)

### 📌 Pré‑requisitos

- MySQL Server 8.0+
- MySQL Workbench (recomendado)

### ⚙️ Passo a passo

1. Abra o **MySQL Workbench** e conecte ao servidor.
2. `File → Open SQL Script` → selecione o arquivo `Sisgesc_run_all.sql`.
3. Clique em **⚡ Execute** (ou `Ctrl + Shift + Enter`).

O script executa automaticamente, em ordem:

1. `reset.sql` – remove bancos antigos (`sisgesc_oltp` e `sisgesc_olap`)
2. `sisgesc_OLTP.sql` – cria todas as tabelas, triggers, views, procedures e eventos
3. `sisgesc_DML_OLTP.sql` – insere dados de exemplo nas 24 tabelas
4. `consultas.sql` – roda consultas analíticas de demonstração
5. `sisgesc_OLAP.sql` – cria e popula o Data Warehouse

### ✅ Verificação pós‑execução

```sql
SHOW DATABASES LIKE 'sisgesc%';       -- sisgesc_oltp e sisgesc_olap devem existir
USE sisgesc_oltp;
SHOW TABLES;                          -- 24 tabelas
SHOW TRIGGERS;                        -- todas as triggers ativas
SHOW EVENTS;                          -- eventos programados
```

Nenhuma mensagem de erro deve aparecer. O sistema estará pronto para uso e análises.

---

## 🛠️ Tecnologias Utilizadas

- MySQL 8.0
- MySQL Workbench
- dbdiagram.io

---

## 👥 Equipe

| Nome                              |
| --------------------------------- |
| Ana Clara Gregório dos Santos     |
| Agatha Ribeiro                    |
| Bruno Oliveira Theodoro           |
| Cauê Porto de Andrade             |
| Dandhara Fernandes de Campos Lima |
| Duquesnio Daniel Bandessa         |
| Gabriela Dias Santos Barros       |
| Kauan Alba Elias                  |
| Rayssa dos Santos                 |
| Yasmim Bueno Miranda da Silva     |

---

## 🏛️ Instituição

Projeto Extensionista desenvolvido para a **UNIVERSIDADE CIDADE DE SÃO PAULO — UNICID**  
Disciplina: Banco de Dados – Ano: 2026

---

## 📚 Considerações Finais

O SisGESC aplica conceitos avançados de modelagem relacional, SQL, automação (triggers, procedures, eventos), governança de dados e preparação para BI/IA. Oferece uma solução robusta, escalável e voltada à gestão educacional e à prevenção da evasão escolar.

---

✅ **Para instalar todo o sistema, execute um único arquivo:** `Sisgesc_run_all.sql`
