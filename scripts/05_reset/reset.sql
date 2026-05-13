-- ================================================================
-- SisGESC — 00_reset.sql
-- Script de Reset Geral
-- ================================================================
-- OBJETIVO:
--   Apagar e recriar os bancos de dados do projeto do zero.
--   Deve ser executado ANTES dos demais scripts para garantir
--   execucao limpa e idempotente em qualquer ambiente.
--
-- ORDEM DE EXECUCAO:
--   1. 00_reset.sql       ← este arquivo
--   2. 01_oltp_ddl.sql
--   3. 02_oltp_dml.sql
--   4. 03_oltp_consultas.sql
--   5. 04_dw.sql
-- ================================================================

-- Desabilita verificacoes de FK para permitir DROP sem restricoes
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------------------------------------------
-- Remove bancos anteriores (todas as nomenclaturas do projeto)
-- ----------------------------------------------------------------
DROP DATABASE IF EXISTS sisgesc_publico_nota;
DROP DATABASE IF EXISTS sisgesc_dw;
DROP DATABASE IF EXISTS sisgesc;

SET FOREIGN_KEY_CHECKS = 1;

-- ----------------------------------------------------------------
-- Recria o banco OLTP
-- ----------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS sisgesc_publico_nota
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Recria o banco DW (OLAP)
-- ----------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS sisgesc_dw
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- ----------------------------------------------------------------
-- Confirmacao visual
-- ----------------------------------------------------------------
SELECT 'Reset concluido. Bancos recriados.' AS status;
SHOW DATABASES LIKE 'sisgesc%';