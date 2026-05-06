-- Migração retroativa: insere titulares em colab_escritorio que ainda não estão lá
-- Safe: usa INSERT ... WHERE NOT EXISTS, não duplica ninguém

-- Caso 1: titulares na tabela `usuarios` (novo modelo de login individual)
INSERT INTO colab_escritorio (escritorio_id, nome, perfil)
SELECT u.escritorio_id, u.nome, 'titular'
FROM usuarios u
WHERE u.perfil = 'titular'
  AND NOT EXISTS (
    SELECT 1 FROM colab_escritorio c
    WHERE c.escritorio_id = u.escritorio_id
      AND c.perfil = 'titular'
  );

-- Caso 2: escritórios legacy (sem registro em `usuarios`) — usa campo `responsavel` de escritorios
INSERT INTO colab_escritorio (escritorio_id, nome, perfil)
SELECT e.id, e.responsavel, 'titular'
FROM escritorios e
WHERE e.responsavel IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM usuarios u WHERE u.escritorio_id = e.id
  )
  AND NOT EXISTS (
    SELECT 1 FROM colab_escritorio c
    WHERE c.escritorio_id = e.id
      AND c.perfil = 'titular'
  );

-- Confirma o resultado
SELECT e.id AS escritorio_id, e.nome AS escritorio, c.nome AS titular, c.perfil
FROM colab_escritorio c
JOIN escritorios e ON e.id = c.escritorio_id
WHERE c.perfil = 'titular'
ORDER BY e.nome;
