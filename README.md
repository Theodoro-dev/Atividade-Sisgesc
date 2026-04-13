# 📋 SisGESC — Sistema de Gestão do CCA Bom Jesus do Cangaíba

> Repositório: `sistema-gestao-sisgesc` | Projeto de Banco de Dados — UNICID

---

## 🗂️ Visão Geral do Projeto

Sistema de banco de dados desenvolvido para gerenciar as operações do **CCA Bom Jesus do Cangaíba**, organizado em quatro módulos integrados: **Acadêmico**, **Serviço Social**, **RH** e **Financeiro**, com foco em integridade referencial e rastreabilidade dos dados da instituição.

---

## 📅 Histórico de Iterações

---

### ✅ Iteração 1 — Levantamento de Requisitos e Arquitetura

**Objetivo:** Mapear as necessidades da instituição e definir os módulos do sistema.

**Entregas:**
- Definição dos 4 módulos: Acadêmico · RH · Financeiro
- Identificação das entidades principais por módulo
- Decisões técnicas: `DECIMAL` para campos financeiros, prefixos `pk_` / `fk_` / `tb_`, snake_case

| Módulo | Responsabilidade |
|---|---|
| 📚 Acadêmico | Alunos, turmas, matrículas, presença |
| 👥 RH | Funcionários, cargos, departamentos |
| 💰 Financeiro | Contratos, pagamentos, receitas |

---

### ✅ Iteração 2 — Modelagem e Script DDL

**Objetivo:** Criar o esquema completo com 17 tabelas em MySQL.

**Tabelas por módulo:**

| Módulo | Tabelas |
|---|---|
| 📚 Acadêmico | `tb_aluno`, `tb_turma`, `tb_matricula`, `tb_presenca`, `tb_curso` |
| 👥 RH | `tb_funcionario`, `tb_cargo`, `tb_departamento` |
| 💰 Financeiro | `tb_contrato`, `tb_pagamento`, `tb_receita`, `tb_despesa`, `tb_categoria_financeira` |

---

### ✅ Iteração 3 — Padronização (Regra de Ouro)

**Objetivo:** Definir convenções de nomenclatura para todo o esquema.

| Elemento | Padrão | Exemplo |
|---|---|---|
| Tabelas | `tb_` + snake_case | `tb_aluno`, `tb_pagamento` |
| Chave Primária | `pk_` + nome | `pk_aluno`, `pk_contrato` |
| Chave Estrangeira | `fk_` + referência | `fk_turma`, `fk_funcionario` |
| Tipos monetários | `DECIMAL(10,2)` | `valor_pagamento` |
| Datas | `DATE` ou `TIMESTAMP` | `dt_matricula`, `criado_em` |
| Auditoria | `criado_em` + `atualizado_em` | Em todas as tabelas |

---

### ✅ Iteração 4 — Diagramas ER

**Objetivo:** Representar visualmente todas as entidades e relacionamentos do sistema.

**Arquivos gerados:**
- `Deerdbdiagram.pdf` — Diagrama ER completo
- `DEERMYSQL.pdf` — Diagrama gerado via MySQL Workbench

---

## 🗃️ Estrutura do Repositório

```
sistema-gestao-sisgesc/
│
├── README.md
├── Sisgesc_Banco_Dados.sql       # Script DDL completo (17 tabelas)
├── Deerdbdiagram.pdf             # Diagrama ER
└── DEERMYSQL.pdf                 # Diagrama MySQL Workbench
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
| Gabriela Dias Santos Barros |
| Kauan Alba Elias |
| Rayssa dos Santos |
| Victor Ferrareto Dias |
| Yasmim Bueno Miranda da Silva |

---

## 🏛️ Instituição

Projeto Extensionista — **UNIVERSIDADE CIDADE DE SÃO PAULO (UNICID)** · Disciplina: Banco de Dados · 2026
