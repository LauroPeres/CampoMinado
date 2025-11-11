.data
    # Constantes do jogo
    TAMANHO:        .word 10        # Tamanho da grade (10x10)
    NUM_MINAS:      .word 10        # Número de minas
    CELULA_OCULTA:  .word -1        # Valor para célula oculta
    CELULA_MINA:    .word -2        # Valor para mina
    CELULA_REVELADA: .word 1        # Flag para célula revelada
    
    # Strings para interface
    titulo:         .asciiz "\n=== CAMPO MINADO ===\n"
    instrucoes:     .asciiz "Digite linha e coluna (0-9): "
    msg_vitoria:    .asciiz "\n PARABÉNS! Voce ganhou! \n"
    msg_derrota:    .asciiz "\n BOOOOOM!!!! Voce perdeu! \n"
    msg_coordenadas: .asciiz "Coordenadas (linha coluna): "
    msg_invalida:   .asciiz "Coordenadas inválidas! Tente novamente.\n"
    separador:      .asciiz "  0   1   2   3   4   5   6   7   8   9\n"
    espaco:         .asciiz " "
    tres_espacos:   .asciiz "   "  # Novo: três espaços para células vazias
    pipe:           .asciiz "|"
    nova_linha:        .asciiz "\n"
    hlinha:          .asciiz "--"
    hlinha_fim:      .asciiz "|\n"
    prompt_linha:   .asciiz "Digite a linha (0-9): "
    prompt_coluna:  .asciiz "Digite a coluna (0-9): "
    
    # Alinhamento para garantir que tabuleiro comece em endereço múltiplo de 4
    .align 2
    tabuleiro:      .space 400      # Tabuleiro principal (10x10 * 4 bytes)
    
    .align 2
    revelado:       .space 400      # Estado das células (reveladas ou não)
    
    # Variáveis do jogo
    celulas_reveladas: .word 0      # Contador de células reveladas
    jogo_terminado:    .word 0      # Flag de fim de jogo
    vitoria:           .word 0      # Flag de vitória

.text	
.globl main 

main:
    jal setTabuleiro
    jal jogaMinas
    
    loop_jogo:
        jal showTabuleiro
        jal getEntrada
        move $a0, $v0
        move $a1, $v1
        jal revelaCelula
        
        jal verificaFim
        beqz $v0, loop_jogo  # Continua se jogo não terminou
    
    # Jogo terminou - mostra resultado
    jal showTabuleiro
    
    lw $t0, vitoria
    beqz $t0, derrota
    
    # Vitória
    la $a0, msg_vitoria
    li $v0, 4
    syscall
    j encerraJogo
    
    # Derrota
    derrota:
    la $a0, msg_derrota
    li $v0, 4
    syscall
    
    # Fim de jogo
    encerraJogo:
    li $v0, 10
    syscall

# Funcao que cria o tabuleiro	
setTabuleiro:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    li $t0, 0                   # contador i == 0 
    lw $t1, TAMANHO            # tamanho = 10
    mul $t1, $t1, $t1          # total = 10 * 10 = 100
    li $t2, 0                   # valor inicial 0
    
    tabLoop:
        beq $t0, $t1, tabFim
        sll $t3, $t0, 2        # t3 = i * 4 
        sw $t2, tabuleiro($t3)
        
        # Inicializa revelado[i] = 0
        sw $zero, revelado($t3)
        
        addi $t0, $t0, 1
        j tabLoop
    
    tabFim:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra	
    
# A função jogaMinas posiciona as minas aleatoriamente no tabuleiro.
# Além de colocar a mina, ela itera sobre as células vizinhas para
# incrementar o contador de minas em cada uma delas (se a célula
# vizinha não for uma mina).

jogaMinas:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Configuração do Gerador de Números Aleatórios
    li $v0, 30        # Syscall para obter tempo do sistema
    syscall
    move $a1, $a0     # Usa o tempo como seed
    li $a0, 0         # ID do gerador
    li $v0, 40        # Syscall para definir seed
    syscall

    lw $t0, NUM_MINAS
    lw $t1, TAMANHO
    
jogaMinasLoop:
    beq $t0, $zero, jogaMinasFim
    
    # Gera coordenadas aleatórias
    li $v0, 42        # Syscall para número aleatório
    li $a1, 10        # Define limite superior como 10
    syscall
    move $t2, $a0     # Linha (0-9)
    
    li $v0, 42
    li $a1, 10        # Define limite superior como 10
    syscall
    move $t3, $a0     # Coluna (0-9)
    
    mul $t4, $t2, $t1
    add $t4, $t4, $t3
    sll $t5, $t4, 2
    
    lw $t6, tabuleiro($t5)
    # Agora, se a célula já for uma mina (valor -2), pula
    lw $t7, CELULA_MINA
    beq $t6, $t7, jogaMinasLoop
    
    # Coloca a mina (substitui o valor por CELULA_MINA)
    sw $t7, tabuleiro($t5)
 
    # Itera sobre os 8 vizinhos da célula onde a mina foi colocada
    # para incrementar seus contadores de minas.
    # $s0 = linha vizinha inicial ($t2 - 1)
    # $s1 = coluna vizinha inicial ($t3 - 1)
    # $s2 = contador de loop para linhas (0 a 2)
    # $s3 = contador de loop para colunas (0 a 2)
    addi $s0, $t2, -1
    addi $s1, $t3, -1
    
    li $s2, 0          # Contador do loop para as 3 linhas (i de -1 a 1)
loop_linha:
    beq $s2, 3, fim_vizinho_loop # Se o contador chegar a 3, saia do loop
    
    li $s3, 0          # Contador do loop para as 3 colunas (j de -1 a 1)
loop_coluna:
    beq $s3, 3, fim_loop_coluna # Se o contador chegar a 3, saia para o próximo loop de linha
   
    # $s4 = linha vizinha atual
    # $s5 = coluna vizinha atual
    add $s4, $s0, $s2
    add $s5, $s1, $s3
    
    # Se a linha ou coluna do vizinho estiver fora dos limites (0-9), pula para o próximo vizinho
    bge $s4, $t1, proximo_vizinho  # Linha >= 10
    blt $s4, $zero, proximo_vizinho # Linha < 0
    bge $s5, $t1, proximo_vizinho  # Coluna >= 10
    blt $s5, $zero, proximo_vizinho # Coluna < 0
    
    # $s6 = índice do vizinho
    # $s7 = offset em bytes do vizinho
    # $s8 = valor da célula vizinha
    mul $s6, $s4, $t1
    add $s6, $s6, $s5
    sll $s7, $s6, 2

    la $t8, tabuleiro      # Carrega o endereço do rótulo 'tabuleiro' no registrador $t8
    add $t8, $t8, $s7      # Adiciona o offset de bytes ($s7) ao endereço base
    lw $t9, 0($t8)         # Usa $t9 em vez de $s8
    
    # Se a célula do vizinho não for uma mina, incrementa seu valor
    lw $t7, CELULA_MINA    # Carrega o valor de CELULA_MINA
    beq $t9, $t7, proximo_vizinho # Se for mina, pula
    addi $t9, $t9, 1       # Incrementa o contador
    sw $t9, 0($t8)         # Armazena o novo valor
    
proximo_vizinho:
    addi $s3, $s3, 1           # Incrementa o contador da coluna
    j loop_coluna                 # Repete para a próxima coluna
    
fim_loop_coluna:
    addi $s2, $s2, 1           # Incrementa o contador da linha
    j loop_linha                 # Repete para a próxima linha
    
fim_vizinho_loop:
    # Decrementa o contador de minas e continua o loop
    addi $t0, $t0, -1
    j jogaMinasLoop
    
jogaMinasFim:
    # Restaura o endereço de retorno ($ra) da pilha
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra                 # Retorna ao chamador
    
# Funç?o para exibir o tabuleiro
showTabuleiro:
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)

    # Imprime o separador com índices das colunas
    la $a0, separador
    li $v0, 4
    syscall

    lw $s1, TAMANHO             # $s1 = tamanho do tabuleiro (10)
    li $s0, 0                   # i = 0

linha_loop:
    beq $s0, $s1, fim_showTabuleiro

    # Imprime linha horizontal
    li $s2, 0
hlinha_loop:
    la $a0, hlinha
    li $v0, 4
    syscall
    addi $s2, $s2, 1
    # Ajuste: multiplicar por 4 porque cada célula tem 4 caracteres (incluindo o pipe)
    mul $t9, $s1, 2
    blt $s2, $t9, hlinha_loop
    
    la $a0, hlinha_fim
    li $v0, 4
    syscall

    # Imprime linha de células
    li $s2, 0                   # j = 0
celula_loop:
    beq $s2, $s1, fim_celula_loop

    # Calcula índice e offset
    mul $t0, $s0, $s1
    add $t0, $t0, $s2
    sll $t0, $t0, 2

    # Verifica se está revelado
    lw $t1, revelado($t0)
    beqz $t1, not_revealed  # Modificado para mostrar espaço vazio

    # Célula revelada
    lw $t2, tabuleiro($t0)
    lw $t3, CELULA_MINA
    beq $t2, $t3, bomb
    beqz $t2, zero

    # Imprime número (formato " X ")
    la $a0, pipe
    li $v0, 4
    syscall
    la $a0, espaco
    li $v0, 4
    syscall
    move $a0, $t2
    li $v0, 1
    syscall
    la $a0, espaco
    li $v0, 4
    syscall
    j proxima_celula

not_revealed:
    # Célula n?o revelada - mostra três espaços
    la $a0, pipe
    li $v0, 4
    syscall
    la $a0, tres_espacos
    li $v0, 4
    syscall
    j proxima_celula

bomb:
    # Imprime mina (formato " B ")
    la $a0, pipe
    li $v0, 4
    syscall
    la $a0, espaco
    li $v0, 4
    syscall
    li $a0, 'B'
    li $v0, 11
    syscall
    la $a0, espaco
    li $v0, 4
    syscall
    j proxima_celula

zero:
    # Imprime zero (formato " 0 ")
    la $a0, pipe
    li $v0, 4
    syscall
    la $a0, espaco
    li $v0, 4
    syscall
    li $a0, '0'
    li $v0, 11
    syscall
    la $a0, espaco
    li $v0, 4
    syscall
    j proxima_celula

proxima_celula:
    addi $s2, $s2, 1
    j celula_loop

fim_celula_loop:
    # Finaliza a linha com o índice da linha
    la $a0, pipe
    li $v0, 4
    syscall
    la $a0, espaco
    li $v0, 4
    syscall
    move $a0, $s0
    li $v0, 1
    syscall
    la $a0, nova_linha
    li $v0, 4
    syscall

    addi $s0, $s0, 1
    j linha_loop

fim_showTabuleiro:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    addi $sp, $sp, 20
    jr $ra
    
# Função para ler e validar entrada do usuário
getEntrada:
    addi $sp, $sp, -12        # Aloca espaço na pilha
    sw $ra, 0($sp)            # Salva endereço de retorno
    sw $s0, 4($sp)            # Salva $s0
    sw $s1, 8($sp)            # Salva $s1

ler_linha:
    # Solicita a linha
    la $a0, prompt_linha      # Carrega endereço do prompt
    li $v0, 4                 # Configura para imprimir string
    syscall                   # Imprime "Digite a linha (0-9): "
    
    li $v0, 5                 # Configura para ler inteiro
    syscall                   # Lê a linha
    move $s0, $v0             # Armazena linha em $s0
    
    # Valida a linha
    blt $s0, 0, linha_invalida # Se linha < 0, inválida
    bgt $s0, 9, linha_invalida # Se linha > 9, inválida
    j ler_coluna              # Linha válida, vai para coluna

linha_invalida:
    la $a0, msg_invalida      # Carrega mensagem de erro
    li $v0, 4                 # Configura para imprimir string
    syscall                   # Imprime mensagem de erro
    j ler_linha               # Volta a solicitar linha

ler_coluna:
    # Solicita a coluna
    la $a0, prompt_coluna     # Carrega endereço do prompt
    li $v0, 4                 # Configura para imprimir string
    syscall                   # Imprime "Digite a coluna (0-9): "
    
    li $v0, 5                 # Configura para ler inteiro
    syscall                   # Lê a coluna
    move $s1, $v0             # Armazena coluna em $s1
    
    # Valida a coluna
    blt $s1, 0, coluna_invalida # Se coluna < 0, inválida
    bgt $s1, 9, coluna_invalida # Se coluna > 9, inválida
    j fim_getEntrada          # Coluna válida, termina

coluna_invalida:
    la $a0, msg_invalida      # Carrega mensagem de erro
    li $v0, 4                 # Configura para imprimir string
    syscall                   # Imprime mensagem de erro
    j ler_coluna              # Volta a solicitar coluna

fim_getEntrada:
    move $v0, $s0             # Retorna linha em $v0
    move $v1, $s1             # Retorna coluna em $v1
    
    lw $ra, 0($sp)            # Restaura endereço de retorno
    lw $s0, 4($sp)            # Restaura $s0
    lw $s1, 8($sp)            # Restaura $s1
    addi $sp, $sp, 12         # Desaloca espaço da pilha
    jr $ra                    # Retorna ao chamador
	
# Função para revelar uma célula e atualizar o estado do jogo
revelaCelula:
    addi $sp, $sp, -24        # Aloca espaço na pilha
    sw $ra, 0($sp)            # Salva endereço de retorno
    sw $s0, 4($sp)            # Salva $s0
    sw $s1, 8($sp)            # Salva $s1
    sw $s2, 12($sp)           # Salva $s2
    sw $s3, 16($sp)           # Salva $s3
    sw $s4, 20($sp)           # Salva $s4

    move $s0, $a0             # Armazena linha em $s0
    move $s1, $a1             # Armazena coluna em $s1

    # Calcula o índice da célula
    lw $t0, TAMANHO
    mul $t1, $s0, $t0
    add $t1, $t1, $s1
    sll $t1, $t1, 2           # Offset em bytes

    # Verifica se a célula já está revelada
    lw $t2, revelado($t1)
    bnez $t2, fim_revelaCelula  # Se já revelada, termina

    # Marca a célula como revelada
    lw $t3, CELULA_REVELADA
    sw $t3, revelado($t1)
    
    # Incrementa contador de células reveladas
    lw $t4, celulas_reveladas
    addi $t4, $t4, 1
    sw $t4, celulas_reveladas

    # Verifica se é uma mina
    lw $t4, tabuleiro($t1)
    lw $t5, CELULA_MINA
    beq $t4, $t5, celula_mina

    # Se não é mina, verifica se é zero
    bnez $t4, fim_revelaCelula  # Se não é zero, termina

    # Se é zero, revela recursivamente os vizinhos
    li $s2, -1                 # dx = -1
loop_dx:
    li $s3, -1                 # dy = -1
loop_dy:
    # Pula a célula central (0,0)
    beqz $s2, checar_dy
    beqz $s3, proximo_dy
    j depois_checar

checar_dy:
    beqz $s3, proximo_dy

depois_checar:
    # Calcula coordenadas do vizinho
    add $s4, $s0, $s2         # linha + dx
    add $t6, $s1, $s3         # coluna + dy

    # Verifica se está dentro dos limites
    blt $s4, 0, proximo_dy       # Linha < 0
    bge $s4, $t0, proximo_dy     # Linha >= TAMANHO
    blt $t6, 0, proximo_dy       # Coluna < 0
    bge $t6, $t0, proximo_dy     # Coluna >= TAMANHO

    # Verifica se o vizinho não é uma mina
    mul $t7, $s4, $t0
    add $t7, $t7, $t6
    sll $t7, $t7, 2
    lw $t8, tabuleiro($t7)
    beq $t8, $t5, proximo_dy     # Se for mina, pula

    # Chama revelaCelula recursivamente para o vizinho
    move $a0, $s4
    move $a1, $t6
    jal revelaCelula

proximo_dy:
    addi $s3, $s3, 1          # Incrementa dy
    ble $s3, 1, loop_dy       # Continua se dy <= 1

    addi $s2, $s2, 1          # Incrementa dx
    ble $s2, 1, loop_dx       # Continua se dx <= 1

    j fim_revelaCelula

celula_mina:
    # Define fim de jogo por mina
    li $t0, 1
    sw $t0, jogo_terminado

fim_revelaCelula:
    lw $ra, 0($sp)            # Restaura endereço de retorno
    lw $s0, 4($sp)            # Restaura $s0
    lw $s1, 8($sp)            # Restaura $s1
    lw $s2, 12($sp)           # Restaura $s2
    lw $s3, 16($sp)           # Restaura $s3
    lw $s4, 20($sp)           # Restaura $s4
    addi $sp, $sp, 24         # Desaloca espaço da pilha
    jr $ra                    # Retorna ao chamador
    
# Função para verificar se o jogo terminou (vitória ou derrota)
verificaFim:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Verifica se o jogo terminou por mina
    lw $t0, jogo_terminado
    bnez $t0, fim_derrota
    
    # Calcula total de células não-minadas que precisam ser reveladas
    lw $t1, TAMANHO
    mul $t2, $t1, $t1        # Total de células
    lw $t3, NUM_MINAS        # Número de minas
    sub $t4, $t2, $t3        # Células não-minadas
    
    # Conta células reveladas
    li $t5, 0                # Contador de células reveladas
    li $t6, 0                # Índice do array
    
contar_reveladas:
    beq $t6, $t2, verificar_vitoria
    
    sll $t7, $t6, 2          # Offset em bytes
    lw $t8, revelado($t7)    # Carrega estado de revelaç?o
    beqz $t8, proxima_celula_soma # Se n?o revelada, pula
    
    addi $t5, $t5, 1         # Incrementa contador
    
proxima_celula_soma:
    addi $t6, $t6, 1
    j contar_reveladas

verificar_vitoria:
    # Verifica se todas as células não-minadas foram reveladas
    bne $t5, $t4, jogo_continua
    
    # Vitória: todas as células seguras reveladas
    li $t9, 1
    sw $t9, vitoria
    li $v0, 1                # Retorna 1 (jogo terminou)
    j fim_verificaFim

fim_derrota:
    li $v0, 1                # Retorna 1 (jogo terminou)
    j fim_verificaFim

jogo_continua:
    li $v0, 0                # Retorna 0 (jogo continua)

fim_verificaFim:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra