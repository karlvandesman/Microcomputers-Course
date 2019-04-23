;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
;*        T�tulo: M�quina preparadora de Cuba Libre (Exerc�cio 1)		     				           *
;* 																									   *
;* 		Disciplina: Microcomputadores				Semestre: 2017.1								   *
;* 		Professor:	Mauro Rodrigues dos Santos														   *                              
;*		                                                         								 	   *
;*      Desenvolvido por:											                                   *
;*   	=> 	Guilherme de Souza Bastos                                                                  *
;*   	=> 	Karl Vandesman de Matos Sousa															   *
;*										   									                           *
;*      VERS�O: 2.0                            		DATA:08/05/2017                                    *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
;*                                     DESCRI��O DO ARQUIVO                                            *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 

; Projeto de um sistema utilizando o PIC16F628A para controle autom�tico de quatro m�quinas para fazer
; uma bebida chamada Cuba Libre, feita com uma dose de rum, quatro cubos de gelo, uma fatia de lim�o e
; 250ml de Coca-Cola. As m�quinas realizam as seguintes atividades:
;                 
; 	- A m�quina M1 fornece uma dose de rum toda vez que for ativada;                      
;   - A m�quina M2 fornece um cubo de gelo toda vez que for ativada;
;	- A m�quina M3 fornece uma fatia de lim�o toda vez que for ativada;
;	- A m�quina M4, quando ativada, fornece Coca-Cola e ap�s escoar 250ml gera um sinal de sa�da S=1,
;	  sinalizando o fim da prepara��o da bebida.
;
; As m�quinas s�o acionadas a partir de um pulso de Ta segundos. 
; As m�quinas devem ser reabastecidas ap�s a prepara��o de N Cubas Libres (capacidade de abastecimento)
; e para isso, � necess�rio o acionamento informando que a m�quina foi reabastecida.
                                                                                                                                    
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
;*                     ARQUIVOS DE DEFINI��ES E CONFIGURA��ES                                          *            
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 

	#INCLUDE <P16F628A.INC>		;Arquivo padr�o da Microchip para o PIC16F628A
	RADIX		DEC				;Define o Decimal como forma padr�o ("default" do programa)
								;n�o sendo necess�rio expressar o n�mero como .XX

	__CONFIG _BOREN_ON & _CP_OFF & _PWRTE_ON & _WDT_OFF & _LVP_OFF & _MCLRE_ON ;Brown-out reset habilitado (prote��o contra alimenta��o fraca)
																				;Prote��o de c�digo desabilitado
																				;Power-up Timer Enable hablitado
																				;Watchdog timer desabilitado
																				;Programa��o de baixa voltagem desabilitado
																				;Masterclear habilitado
	#DEFINE	BANK0	BCF STATUS, RP0	;Defini��o de comandos para altera��o	
	#DEFINE	BANK1	BSF STATUS, RP0	;da p�gina de mem�ria de dados

	#DEFINE ZERO  		STATUS,Z			;Flag Z do registrador STATUS

	#DEFINE	T0_FLAG		INTCON,	T0IF		;Flag que sinaliza estouro do Timer
	#DEFINE	PREP_FLAG	INTCON, INTF		;Flag que sinaliza interrup��o externa
	#DEFINE	PORTB_FLAG	INTCON, RBIF		;Flag que sinaliza altera��o no pino RB6 ou RB7, 
											;avisando que a m�quina M4 finalizou o trabalho

	#DEFINE	HAB_GERAL	INTCON, GIE			;Habilita as interrup��es (� necess�ria ainda a habilita��o individual 
											;de cada interrup��o)
	#DEFINE HAB_RB		INTCON, RBIE		;Habilita as interrup��es por mudan�a de estado das portas RB<4:7>
	#DEFINE	HAB_TMR0	INTCON, T0IE		;Habilita a interrup��o do Timer 0
	#DEFINE	HAB_PREP	INTCON, INTE		;Habilita a interrup��o do bot�o preparar (RB0)

	#DEFINE	DELAY_OK	REG_DELAY, 0		;Determinar esse bit para avisar que houve o tempo de delay


;*************************************************** 
;*       			 VARI�VEIS                     *                   
;*************************************************** 
;Defini��o do bloco de vari�veis 
	CBLOCK 0x20				;Endere�o inicial da mem�ria do usu�rio						
		AUX_PULSOS			;Vari�vel auxiliar para contagem do n�mero de pulsos para a m�quina M2
		N					;Quantidade de bebidas que ainda podem ser feitas
		W_TEMP
		STATUS_TEMP
		REG_DELAY
	ENDC				    ;Fim do bloco de vari�veis

;*************************************************** 
;*      		     CONSTANTES                    *                   
;*************************************************** 
;Defini��o de constantes utilizadas no programa

TA			EQU		246		;Delay de (255-Ta)/10 segundos (Com clock externo de 10Hz)
							;para ativa��o das m�quinas M1, M2, M3 e M4
N_INIC		EQU		15		;Valor inicial da quantidade de Cuba libres que podem ser preparadas
;*************************************************** 
;*      			  ENTRADAS                     *                   
;*************************************************** 
; Defini��o de todos os pinos que ser�o utilizados como entrada

	#DEFINE		OSC			PORTA, RA4		;Oscilador externo (necessidade de delay muito grande)
	#DEFINE		PARTIDA 	PORTA, RA5  	;Bot�o de partida (ligamento da m�quina e prepara��o das vari�veis)
	#DEFINE 	PREPARAR	PORTB, RB0	 	;Bot�o para come�ar preparamento da bebida (Interrup��o externa)
	#DEFINE		CARREGAR	PORTB, RB6		;Bot�o para o usu�rio reabastecer os materiais das m�quinas (rum, gelo, etc.)
	#DEFINE		S			PORTB, RB7		;Sinal enviado por M4 avisando que j� escoou 250ml de Coca-Cola

;*************************************************** 
;*                     SA�DAS                      *                   
;*************************************************** 
; Defini��o de todos os pinos que ser�o utilizados como sa�da

	#DEFINE 	M1				PORTB, RB1		;M�quina 1 (fornece dose de rum)
	#DEFINE 	M2				PORTB, RB2		;M�quina 2 (fornece um cubo de gelo)
	#DEFINE 	M3				PORTB, RB3		;M�quina 3 (fornece uma fatia de lim�o)
	#DEFINE 	M4				PORTB, RB4		;M�quina 4 (fornece 250ml de Coca-Cola e envia sinal de sa�da S=1)
	#DEFINE		LED_CARREGAR	PORTB, RB5		;Sinaliza que n�o h� material para realiza�o da cuba libre, e � necess�ria a recarga	

	#DEFINE 	LED_PREPARANDO	PORTA, RA6		;Sinaliza que est� em andamento a prepara��o da bebida
	#DEFINE 	LED_FIM			PORTA, RA7		;Sinaliza t�rmino do preparo da bebida
		
	#DEFINE 	D1				PORTA, RA0		;4 Segmentos para acionamento do Display de 7 segmentos, que
	#DEFINE 	D2				PORTA, RA1		;j� possui decodificador interno
	#DEFINE 	D3				PORTA, RA2		; 
	#DEFINE 	D4				PORTA, RA3	

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                         VETOR DE RESET                                  *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

	ORG		0x00	    	;Endere�o inicial de processamento
	GOTO	INICIO

;***************************************************
;*				IN�CIO DA INTERRUP��O		       *
;***************************************************
	ORG		0x04		;Endere�o inicial da interrup��o
SALVA_CONTEXTO
	BCF		HAB_GERAL	;Desabilita interrup��es gerais
	MOVWF	W_TEMP		;Copia W para a vari�vel tempor�ria W_TEMP
	SWAPF	STATUS,W	;Realiza a opera��o de SWAP em Status e armazena em W,
						;essa opera��o � feita para n�o afetar os flags da vari�vel STATUS
	MOVWF	STATUS_TEMP	;Copia o registro W (STATUS "invertido" pelo SWAP) em STATUS_TEMP
	
;***************************************************
;*	   ROTINA DE ATENDIMENTO DAS INTERRUP��ES	   *
;***************************************************
VERIFICA_FLAGS				;Verifica��o dos Flags que podem ter gerado interrup��o
	BTFSC	T0_FLAG			;Testa se ocorreu interrup��o do TMR0
	GOTO 	TRATA_TMR0		;Se sim, trata essa interrup��o
	BTFSC	PORTB_FLAG		;Testa a flag das interrup��es geradas por PORTB (S e Carregar)
	GOTO	TRATA_PORTB		;Se sim, trata essa interrup��o
	BTFSC	PREP_FLAG		;Testa se ocorreu interrup��o por RB0 (Preparar) 
	GOTO	TRATA_PREPARAR	;Se sim, trata essa interrup��o

	GOTO	SAI_INT			;Caso nenhum flag esteja ativado, sai da interrup��o

TRATA_TMR0
	BCF		T0_FLAG		;Limpa o flag de estouro do Timer0	
	BCF		HAB_TMR0	;Desabilita a interrup��o do Timer0
	MOVLW 	TA			;Move o valor do delay (TA)
	MOVWF 	TMR0		;Move o valor de delay de TA para TMR0
	BSF		DELAY_OK	;Avisa que o tempo de delay j� passou		
	GOTO	SAI_INT		;Sai interrup��o

TRATA_PREPARAR
	BCF		PREP_FLAG	;Limpa a flag de prepara��o
	BCF		HAB_PREP	;Desabilita a interrup��o do Preparar
						;Agora � necess�rio verificar se h� material para realiza��o da Cuba Libre
	MOVF	N, W		;Move o valor de N para o acumulador W
	BTFSC	ZERO		;Caso o valor de N seja zero, o sinalizador Z estar� setado
	GOTO	SAI_INT		;� sinalizado que n�o h� materiais, e sai da interrup��o

	BCF		LED_FIM			;Apaga o LED fim 
	BSF		LED_PREPARANDO	;Acende o LED preparando, avisando que a bebida est� sendo feita
	
	GOTO	SAI_INT		;Depois de tratada, sai da interrup��o

TRATA_PORTB			;Existem 2 pinos de entrada que podem gerar interrup��o
					;por mudan�a de estado em PORTB: RB6 (Carregar) e
					;RB7 (S, que sinaliza termino da M�quina 4)

	BCF		PORTB_FLAG	;Limpa a flag por PORTB. 2 interrup��es podem gerar flag dessa interrup��o
	BTFSC	CARREGAR	;Testa se a interrup��o foi Carregar
	GOTO	TRATA_CARREGAR ;Se sim, trata carregar
	BTFSC	S			;Testa se a interrup��o foi S
	GOTO	TRATA_S		;Se sim, trata S
	GOTO	SAI_INT		;Caso n�o, sai da interrup��o

TRATA_S
	BCF		PREP_FLAG
	BTFSS	M4				
	GOTO	SAI_INT	
	BCF		M4

	GOTO	SAI_INT

TRATA_CARREGAR
	MOVLW	N_INIC
	MOVWF	N	
	CALL	DISPLAY
	GOTO	SAI_INT

;****************************************************
;*			     SA�DA DA INTERRUP��O         		*
;****************************************************
SAI_INT						;Antes de sair da interrup��o � necess�rio retornar o contexto (recuperar os valores dos registros STATUS e W)
	SWAPF	STATUS_TEMP,W
	MOVWF	STATUS			;Move STATUS_TEMP para STATUS
	SWAPF	W_TEMP, F	
	SWAPF	W_TEMP, W
	BSF		HAB_GERAL
	RETFIE	

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                  DEFINI��O DE ROTINAS E SUB-ROTINAS                     *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

;*************************************************** 
;*ROTINA QUE SINALIZA DE ESVAZIAMENTO DAS M�QUINAS *                   
;*************************************************** 
;Com N=0, � necess�rio o reabastecimento das m�quinas
SINALIZA_CARREGAR
	BCF		LED_PREPARANDO		

	BSF		LED_CARREGAR
	CALL	AGUARDA_TMR0	
	BCF		LED_CARREGAR
	CALL	AGUARDA_TMR0
	BSF		LED_CARREGAR
	CALL	AGUARDA_TMR0
	BCF		LED_CARREGAR
	GOTO	AGUARDA_ACIONAMENTO

;*************************************************** 
;*        ROTINA DE ACIONAMENTO DE M�QUINAS        *                   
;***************************************************
ACIONA_MAQ


	DECF	N, 1			;Decrementa 1 unidade na quantidade de cuba libres que podem ser feitas
	CALL	DISPLAY			;Apresenta o valor de N no display de 7 seg

	BSF		M1				;Aciona a M�quina M1
	CALL	AGUARDA_TMR0
	BCF		M1				;Para o acionamento de M1
	CALL	AGUARDA_TMR0		;Liga interrup��o de TMR0 e espera para formar o pulso de acionamento

	MOVLW	4				;Atribuindo valor 4 para AUX_PULSOS
	MOVWF	AUX_PULSOS		;Para determinar 4 pulsos de acionamento para M2
	BSF		M2				;Aciona a M�quina M2
	CALL	AGUARDA_TMR0		;Liga interrup��o de TMR0 e espera para formar o pulso de acionamento
	BCF		M2				;Para o acionamento de M2
	CALL	AGUARDA_TMR0		;Liga interrup��o de TMR0 e espera para formar o pulso de acionamento
	DECFSZ	AUX_PULSOS		;Decrementa AUX_PULSOS e testa se � zero
	GOTO	$-5				;Caso AUX_PULSOS>0, volta 5 instru��es onde se 
							;iniciou acionamento de M2
	BSF		M3				;Aciona a M�quina M3
	CALL	AGUARDA_TMR0		;Liga interrup��o de TMR0 e espera para formar o pulso de acionamento
	BCF		M3				;Para o acionamento de M3
	CALL	AGUARDA_TMR0		;Liga interrup��o de TMR0 e espera para formar o pulso de acionamento

	BSF		M4				;Aciona a M�quina M4
	
	RETURN	

;*************************************************** 
;*       	     ROTINA DE DELAY		           *                   
;***************************************************
						;Rotina de gera��o de delay a partir do contador Timer0 
AGUARDA_TMR0
	BCF		DELAY_OK		;Limpa-se o bit DELAY_OK, que � setado na interrup��o de TMR0
	MOVLW	TA				;Valor inicial de TMR0 � atribu�do
	MOVWF	TMR0
	BSF		HAB_TMR0		;� habilitado a interrup��o de TMR0
DELAY_TA
	BTFSS 	DELAY_OK		;A contagem do delay terminou?
	GOTO 	$-1				;Caso n�o tenha terminado, volta pra instru��o anterior
							;Aguardando at� que TFLAG estoure (termine a contagem)
	RETURN					;Retorna o desvio de chamada

;*************************************************** 
;* ROTINA DE ACIONAMENTO DO DISPLAY DE 7 SEGMENTOS *                   
;***************************************************
DISPLAY
	MOVLW	B'11110000'			;Mant�m os 4 MSB (pinos diversos) e limpa os LSB
	ANDWF	PORTA, 1			;Opera��o AND bit a bit entre W e PORTA
								;zera os 4 LSB (display)
	MOVF	N, W				;Move valor de N para o acumulador W
	IORWF	PORTA, 1			;Realiza opera��o OR entre W e PORTA,
								;e guarda resultado em PORTA, acionando
								;os 4 bits (LSB) do Display e mantendo inalterado
								;os outros 4 bits (MSB) de PORTA

	RETURN						;Retorno da rotina de chamada

;*************************************************** 
;*  DEFINE AS HABILITA��ES INICIAIS DE INTERRUP��O *                   
;***************************************************

INICIA_INT
	BSF		HAB_GERAL		;Aqui s�o habilitadas as interrup��es iniciais que ser�o consideradas,
	BSF		HAB_PREP		;assim, somente a interrup��o por TMR0 � desabilitada
	BSF		HAB_RB
	BCF		HAB_TMR0
	RETURN

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                     IN�CIO DO PROGRAMA                                  *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;Configura��o de opera��o do microcontrolador
INICIO
	BANK1					;Altera para o Banco 1 da mem�ria de dados
	MOVLW	B'00110000'		;Configura PORTA como entrada ou sa�da
	MOVWF	TRISA			;IN: RA4, RA5.	OUT: RA0, RA1, RA2, RA3, RA6 RA7
		
	MOVLW	B'11000001'		;Configura PORTB como entrada ou sa�da
	MOVWF	TRISB			;IN: RB0, RB6, RB7.	OUT: RB1, RB2, RB3, RB4, RB5							
	
	MOVLW	B'11101000'		;OPTION_REG: RBPU|INTEDG|T0CS|T0SE|PSA|PS2|PS1|PS0
	MOVWF	OPTION_REG 		;habilita pull-ups portb|fonte de clock ser� RA4/T0CKI|sem prescaler pra TMR0|0|0|0

	MOVLW	B'00001000' 	;Utilizar cristal interno de 4MHz
	MOVWF	PCON

	MOVLW	B'10111000'		;Habilitar os bits de interrup��es: geral (GIE), do timer 0 (TMR0),
	MOVWF	INTCON			;externa (INTE), e por mudan�a na porta B (RBIE).
	
	
	BANK0					;Altera para o Banco 0 da mem�ria de dados

	MOVLW	B'00000111'
	MOVWF	CMCON			;Desativando as entradas anal�gicas

;************************************************* 
;*          INICIALIZA��O DAS VARI�VEIS          *                   
;*************************************************
INIC_VAR					;Inicializa as vari�veis
	CLRF	PORTA			;Zera PORTA A
	CLRF    PORTB			;Zera PORTA B
	CLRF	AUX_PULSOS		;Zera Vari�vel Auxiliar
	CLRF	W_TEMP			;Zera o W_TEMP
	CLRF	STATUS_TEMP		;Zera o STATUS_TEMP
	MOVLW	N_INIC			;Valor inicial da quantidade 	
	MOVWF	N				;de bebidas que podem ser preparadas
	CLRF	REG_DELAY

LIGAR					
	BTFSS	PARTIDA			;Testa o pino PARTIDA
	GOTO	$-1				;Aguarda PARTIDA=1 para entrar na rotina principal

;************************************************* 
;*               ROTINA PRINCIPAL                *                   
;*************************************************
MAIN_LOOP
	CALL	INICIA_INT
	CALL 	DISPLAY			;Aciona o Display com o valor de N

AGUARDA_ACIONAMENTO
	CALL	INICIA_INT
	SLEEP					;Aguarda interrup��o ou Reset
	NOP						;Ao ocorrer interrup��o (RB0, RB6 ou RB7), o sistema trata ela e volta pro Main_loop

	MOVF	N, W		;Move o valor de N para o acumulador W
	BTFSC	ZERO		;Caso o valor de N seja zero, o sinalizador Z estar� setado
	GOTO	SINALIZA_CARREGAR	;E com N sendo zero, ser� sinalizado ao usu�rio que � necess�rio recarga
	
	BTFSS	PREPARAR			;Caso N>0, � verificado se o MCU saiu do SLEEP pela interrup��o do Preparar
	GOTO	AGUARDA_ACIONAMENTO ;Caso outra interrup��o tenha feito o MCU sair do sleep, ele volta novamente a rotina e entra em sleep

	CALL	ACIONA_MAQ			;Caso tenha sa�do da interrup��o por preparar e N>0, come�a o acionamento das m�quinas

	BSF		HAB_RB				;Aqui � habilitado a interrup��o por mudan�a de estado em RB (CARREGAR e S)
AGUARDA_S
	SLEEP					;Aguarda interrup��o somente de S (todas as outras est�o desabilitadas) 
	NOP
	BTFSS	S				;Quando se sai do sleep, depois do tratamento da interrup��o, � verificado se foi pressionado S
	GOTO	AGUARDA_S		
							;Com a interrup��o de S e devido tratamento, a bebida foi preparada e o 
							;sistema retorna ao ponto inicial

	BCF		LED_PREPARANDO		;Fim da prepara��o da bebida, LED PREPARANDO se apaga
	BSF		LED_FIM				;e LED FIM acende
	CALL	AGUARDA_TMR0
	GOTO	MAIN_LOOP		;Retorna para o come�o da rotina MAIN_LOOP

;XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
;X                FIM DO PROGRAMA                X                   
;XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
	END