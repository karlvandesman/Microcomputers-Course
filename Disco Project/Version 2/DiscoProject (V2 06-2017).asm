;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
;*        T�tulo: Controle de ilumina��o e temperatura em Discoteca (Trabalho 2)			           *
;* 																									   *
;* 		Disciplina: Microcomputadores				Semestre: 2017.1								   *
;* 		Professor:	Mauro Rodrigues dos Santos														   *                              
;*		                                                         								 	   *
;*      Desenvolvido por:											                                   *
;*   	=> 	Guilherme de Souza Bastos                                                                  *
;*   	=> 	Karl Vandesman de Matos Sousa															   *
;*										   									                           *
;*      VERS�O: 2.0                            		DATA:02/06/2017                                    *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
;*                                     DESCRI��O DO ARQUIVO                                            *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 

; Este projeto trata do controle de ilumina��o e temperatura interna de uma discoteca, integrando o sal�o 
; e o bar, de forma a economizar energia. O sistema ser� composto de um sensor de temperatura LM35, um  
; conjunto de ventiladores, perando por PWM e quatro ar-condicionados. A luminosidade ser� controlada com 
; um LDR e quatro conjuntos de lumin�rias. H� tamb�m um sensor de presen�a, e caso seja detectado que n�o
; h� ningu�m no ambiente, todas as sa�das s�o desativadas.
	
;				* * * * * * * * * * * * * * * * * * * * * 
;				* Par�metros no Controle de Temperatura *
;				* * * * * * * * * * * * * * * * * * * * *
;_Faixa de temperatura__|___ventiladores_(PWM)__|___Ar1_|___Ar2	|___Ar3_|___Ar4___                                           
; 		<=20�C			|		10% Pmax		|  DESL	|  DESL	|  DESL	|	DESL
; 	>20�C a <=25�C		|		30% Pmax		|	LIG	|  DESL |  DESL |	DESL
; 	>25�C a <=30�C		|		75% Pmax		| 	LIG	|	LIG |  DESL	|	DESL
;		>30�C			|		90% Pmax		|	LIG	|	LIG	|	LIG	|	LIG                                           
                                                                               
;			* * * * * * * * * * * * * * * * * * * * * 
;			* Par�metros no Controle de Luminosidade*
;			* * * * * * * * * * * * * * * * * * * * *
;___Luz ambiente____|___Lum1____|___Lum2____|___Lum3____|___Lum4____
;	   Claro		|	desl	|	desl	|	desl	|	desl
;	   Sombra		|	lig		|	desl	|	lig		|	desl
;	   Escuro		|	lig		|	lig		|	lig		|	lig
                                                          
; Nesta vers�o 2.0, ser�o utilizadas interrup��es do Timer 0, do Conversor A/D, interrup��o externa
; de RB0 (sensor de presen�a)                                                          
                                                                                                                                  
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
;*                     ARQUIVOS DE DEFINI��ES E CONFIGURA��ES                                          *            
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 

	#INCLUDE <P16F877A.INC>		;Arquivo padr�o da Microchip para o PIC16F877A
	RADIX		DEC				;Define o Decimal como forma padr�o ("default" do programa)
								;n�o sendo necess�rio expressar o n�mero como .XX

	__CONFIG _BOREN_ON & _CP_OFF & _PWRTE_ON & _WDT_OFF & _LVP_OFF	;Brown-out reset habilitado (prote��o contra alimenta��o fraca)
																	;Prote��o de c�digo desabilitado
																	;Power-up Timer Enable hablitado
																	;Watchdog timer desabilitado
																	;Programa��o de baixa voltagem desabilitado
																
	#DEFINE	BANK0	BCF STATUS, RP0	;Defini��o de comandos para altera��o	
	#DEFINE	BANK1	BSF STATUS, RP0	;da p�gina de mem�ria de dados

	#DEFINE ZERO  		STATUS,Z				;Flag Z do registrador STATUS

	#DEFINE	FLAG_TMR0		INTCON,	T0IF		;Flag que sinaliza estouro do Timer 0
	#DEFINE	FLAG_PRESENCA	INTCON, INTF		;Flag que sinaliza interrup��o externa
	#DEFINE FLAG_CONV		PIR1, ADIF			;Flag que sinaliza fim da convers�o A/D

	#DEFINE	HAB_GERAL		INTCON, GIE			;Habilita as interrup��es (� necess�ria ainda a habilita��o individual 
												;de cada interrup��o)
	#DEFINE	HAB_TMR0		INTCON, T0IE		;Habilita a interrup��o do Timer 0
	#DEFINE	HAB_PRESENCA	INTCON, INTE		;Habilita a interrup��o do bot�o preparar (RB0)
	#DEFINE	HAB_CONV		PIE1, ADIE			;Habilita a interrup��o do conversor A/D

	#DEFINE	DELAY_OK	REG_DELAY, 0			;Determinar esse bit para avisar que houve o tempo de delay

	#DEFINE LIGA_CONV	ADCON0, 2	    ;Bit que controla o in�cio/fim da convers�o
	#DEFINE PWM			CCPR1L	        ;Vari�vel comprimento do pulso do PWM
	#DEFINE CARRY		STATUS, C       ;Flag que indica carry out
	#DEFINE	SEL_CANAL	ADCON0, 3		;Os bits 3 a 5 de ADCON0 s�o respons�veis por sele��o 
										;do canal anal�gico que ser� convertido no Conversor A/D
										;Como est�o sendo usadas apenas 2 portas anal�gicas, ser�
										;modificado apenas o bit 3 para sele��o do canal
	#DEFINE RESULT_CONV	ADRESL		    ;Vari�vel que guarda parte da convers�o (parte baixa, 8 bits)

;*************************************************** 
;*       			 VARI�VEIS                     *                   
;*************************************************** 
;Defini��o do bloco de vari�veis 
	CBLOCK 0x20				;Endere�o inicial da mem�ria do usu�rio						
		N					;Quantidade de bebidas que ainda podem ser feitas
		W_TEMP				;Vari�vel para salvar contexto de W
		STATUS_TEMP			;Vari�vel para salvar contexto de STATUS
		REG_DELAY			;Vari�vel que ser� utilizada com a interrup��o do timer0
		
		TEMPERATURA_VAR		;Vari�vel para armazenar o resultado da convers�o A/D do sensor de temperatura
		LUMINOSIDADE_VAR	;Vari�vel para armazenar o resultado da convers�o A/D do sensor de luminosidade

		AUX_TEMP			;Utilizada para o pequeno delay na casa dos microssegundos	
	ENDC				    ;Fim do bloco de vari�veis

;*************************************************** 
;*      		     CONSTANTES                    *                   
;*************************************************** 
;Defini��o de constantes utilizadas no programa
TA			EQU		250		;Delay de (255-Ta)/10 segundos (Com clock externo de 10Hz)
							;Delay=20s, intervalo de medi��o dos sensores
							
TEMP_20		EQU		41		;N�mero digital equivalente a 20�C (1023 -> 5V, 0-> 0V)	
TEMP_25		EQU		52		;N�mero digital equivalente a 25�C (1023 -> 5V, 0-> 0V)	
TEMP_30		EQU		62		;N�mero digital equivalente a 30�C (1023 -> 5V, 0-> 0V)	

NIVEL_LUZ_1	EQU		45			;N�mero digital equivalente a 50 Lux
NIVEL_LUZ_2	EQU		156 		;N�mero digital equivalente a 250 Lux
;*************************************************** 
;*      			  ENTRADAS                     *                   
;*************************************************** 
; Defini��o de todos os pinos que ser�o utilizados como entrada
	#DEFINE		LUMINOSIDADE	PORTA, RA0	;Sensor de Luminosidade com LDR (Entrada anal�gica)
	#DEFINE		TEMPERATURA		PORTA, RA1	;Sensor de temperatura com LM35 (Entrada anal�gica) 
	#DEFINE		OSC				PORTA, RA4	;Oscilador externo (necessidade de delay muito grande)

	#DEFINE		PRESENCA	 	PORTB, RB0 	;Sensor de presen�a, usado para economia de energia (desligar os dispositivos 
											;independente das leituras de luminosidade e temperatura)

;*************************************************** 
;*                     SA�DAS                      *                   
;*************************************************** 
; Defini��o de todos os pinos que ser�o utilizados como sa�da

	#DEFINE 	LIGADO			PORTB, RB1		;Indica se a o MCU est� ligado ou n�o
	
	#DEFINE		VENTILADOR		PORTC, RC2		;Sa�da PWM para ativamento do conjunto de ventiladores
	
	#DEFINE		AR1		PORTD, RD0		;Ar condicionado 1
	#DEFINE		AR2		PORTD, RD1		;Ar condicionado 2
	#DEFINE		AR3		PORTD, RD2		;Ar condicionado 3
	#DEFINE		AR4		PORTD, RD3		;Ar condicionado 4
	
	#DEFINE		LUM1	PORTD, RD4		;Lumin�ria 1
	#DEFINE		LUM2	PORTD, RD5		;Lumin�ria 2
	#DEFINE		LUM3	PORTD, RD6		;Lumin�ria 3
	#DEFINE		LUM4	PORTD, RD7		;Lumin�ria 4
		
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
	BTFSC	FLAG_PRESENCA	;Testa se ocorreu interrup��o externa  por RB0 pelo sensor de presen�a
	GOTO	TRATA_PRESENCA 	;Se sim, trata essa interrup��o
	
	BTFSC	FLAG_TMR0		;Testa se ocorreu interrup��o do TMR0
	GOTO 	TRATA_TMR0		;Se sim, trata essa interrup��o
	
	BTFSC	FLAG_CONV		;Testa se ocorreu interrup��o do conversor A/D
	GOTO	TRATA_CONV		;Se sim, trata essa interrup��o

	GOTO	SAI_INT			;Caso nenhum flag esteja ativado, sai da interrup��o

TRATA_PRESENCA
	BCF		FLAG_PRESENCA	;Limpa o flag gerado pelo sensor de presen�a

	GOTO	SAI_INT			;Sai da interrup��o
	
TRATA_TMR0
	BCF		FLAG_TMR0	;Limpa o flag de estouro do Timer0	
	BCF		HAB_TMR0	;Desabilita a interrup��o do Timer0
	MOVLW 	TA			;Move o valor do delay (TA)
	MOVWF 	TMR0		;Move o valor de delay de TA para TMR0
	BSF		DELAY_OK	;Avisa que o tempo de delay j� passou		
	GOTO	SAI_INT		;Sai interrup��o

TRATA_CONV
	BCF		FLAG_CONV	;Limpar flag que sinaliza o fim da convers�o a/d
	BTFSC	SEL_CANAL	;Verifica em qual canal anal�gico ele estava	
	GOTO	CONV_TEMPERATURA	;Se SEL_CANAL=1, est� sendo convertido o valor de temperatura
	GOTO	CONV_LUMINOSIDADE	;Se SEL_CANAL=0, est� sendo convertido o valor de luminosidade
	
CONV_TEMPERATURA
	BANK1					; Move para Bank1 pois ser� usado o registro ADRESL (RESULT_CONV), 
							; que est� no Bank1
							
	MOVF   	RESULT_CONV, W  ; Resultado da convers�o em W e,
	MOVWF	TEMPERATURA_VAR	; Transferido p/ vari�vel temperatura
	BANK0
	
	GOTO	SAI_INT			;Sai da interrup��o
	
CONV_LUMINOSIDADE
	BANK1					; Move para Bank1 pois ser� usado o registro ADRESL (RESULT_CONV), 
							; que est� no Bank1
							
	MOVF   	RESULT_CONV, W  ; Resultado da convers�o em W e,
	MOVWF	LUMINOSIDADE_VAR; Transferido p/ vari�vel temperatura
	BANK0

	GOTO	SAI_INT			;Sai da interrup��o
	
;****************************************************
;*			     SA�DA DA INTERRUP��O         		*
;****************************************************
SAI_INT						;Antes de sair da interrup��o � necess�rio retornar o contexto (recuperar os valores dos registros STATUS e W)
	SWAPF	STATUS_TEMP,W
	MOVWF	STATUS			;Move STATUS_TEMP para STATUS
	SWAPF	W_TEMP, F		;Resgata o valor de W a partir de W_TEMP
	SWAPF	W_TEMP, W		
	BSF		HAB_GERAL		
	RETFIE	

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                  DEFINI��O DE ROTINAS E SUB-ROTINAS                     *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

;*************************************************** 
;*        ROTINA DE LEITURA DE LUMINOSIDADE        *                   
;***************************************************
LER_LUMINOSIDADE
	BANK0
	BCF		SEL_CANAL		;Sele��o do canal de multiplexa��o do conversor A/D
							;CHS2:CHS0 -> 3 bits respons�veis pela sele��o do canal
							;001 -> Entrada anal�gica 0 (RA0)

	MOVLW	160				;Ap�s mudan�a de canal, � necess�rio um tempo para adequa��o do capacitor
	CALL	DELAY_US		;do conversor AD (40us)

	BSF		LIGA_CONV	   	;Inicia convers�o
	
	BTFSC 	LIGA_CONV	    ;Testa fim da convers�o
	GOTO	$-1			    ;Se n�o terminou, volta a testar
	
	BANK0
	
	RETURN	

;*************************************************** 
;*         ROTINA DE LEITURA DE TEMPERATURA        *                   
;***************************************************
LER_TEMPERATURA
	BANK0

	BSF		SEL_CANAL		;Sele��o do canal de multiplexa��o do conversor A/D
							;CHS2:CHS0 -> 3 bits respons�veis pela sele��o do canal
							;001 -> Entrada anal�gica 1 (RA1)

	MOVLW	160				;Ap�s mudan�a de canal, � necess�rio um tempo para adequa��o do capacitor
	CALL	DELAY_US		;do conversor AD (40us)
							
	BSF		LIGA_CONV	   	;Inicia convers�o
	
	BTFSC 	LIGA_CONV	    ;Testa fim da convers�o
	GOTO	$-1			    ;Se n�o terminou, volta a testar
	
	BANK0

	RETURN

;*************************************************** 
;*        ROTINA DE CONTROLE DA LUMINOSIDADE       *                   
;***************************************************
CONTROLE_LUMINOSIDADE	
							;Para o controle, � comparado o valor lido no sensor com constantes
	MOVLW	NIVEL_LUZ_1		;Move para o acumulador o primeiro valor de compara��o de n�vel de luz
	
	BANK1
	SUBWF	LUMINOSIDADE_VAR, W	;Compara o valor lido da luminosidade com o primeiro n�vel de luz
	BTFSS	CARRY				;Verifica-se o carry da subtra��o
	GOTO	LUM_ESCURO			;Se o valor da luminosidade for menor que o primeiro n�vel, significa
								;que Luminosidade � menor que 50 Lux, logo ambiente est� escuro
								
	MOVLW	NIVEL_LUZ_2			;Para verificar o pr�ximo intervalo de luminosidade, � comparado com 
	SUBWF	LUMINOSIDADE_VAR, W	;o segundo n�vel de luminosidade (250 Lux)
	BTFSS	CARRY				
	GOTO	LUM_SOMBRA			;Se o valor do sensor for menor que 250 Lux e maior que 50 Lux, o ambiente est� em sombra
	GOTO	LUM_CLARO			;Se for maior que 250 Lux, est� claro

LUM_CLARO
	BANK0
	BCF		LUM1		;Com o ambiente claro, todas as luzes ficar�o apagadas
	BCF		LUM2
	BCF		LUM3
	BCF		LUM4
	
	RETURN

LUM_SOMBRA
	BANK0
	BSF		LUM1		;Com o ambiente em sombra, 2 lumin�rias ser�o acesas
	BCF		LUM2
	BSF		LUM3
	BCF		LUM4

	RETURN

LUM_ESCURO
	BANK0	
	BSF		LUM1		;Com o ambiente escuro, todas as lumin�rias ser�o ligadas
	BSF		LUM2
	BSF		LUM3
	BSF		LUM4
	
	RETURN

;*************************************************** 
;*        ROTINA DE CONTROLE DA TEMPERATURA        *                   
;***************************************************	
CONTROLE_TEMPERATURA	
	MOVLW	TEMP_20
	BANK1
	SUBWF	TEMPERATURA_VAR, W	;Opera��o TEMPERATURA-20, resultado armazenado em W
	BTFSS	CARRY				;Verifica o carry, se temperatura<20�C, utiliza a pot�ncia m�nima dos ventiladores
	GOTO	POT_MINIMA			;e todos os ares-condicionados ficar�o desligados
	
	MOVLW	TEMP_25
	SUBWF	TEMPERATURA_VAR, W	;Opera��o TEMPERATURA-25, resultado armazenado em W
	BTFSS	CARRY				;Verificado se a temperatura est� entre 20�C e 25�C ou maior que 25�C		
	GOTO	POT_BAIXA
	
	MOVLW	TEMP_30
	SUBWF	TEMPERATURA_VAR, W	;Opera��o TEMPERATURA-30, resultado armazenado em W
	BTFSS	CARRY
	GOTO	POT_ALTA			;Se a temperatura estiver entre 25�C e 30�C, aciona pot�ncia alta
	GOTO	POT_MAXIMA			;Se a temperatura estiver maior que 30�C, aciona a pot�ncia m�xima
	
POT_MINIMA				;Se a temperatura est� menor que 20�C:
;*--- Controle da pot�ncia do conjunto de ventiladores ---*
	BANK0
	MOVLW	26					;Pot�ncia de 10% no conjunto de ventiladores
	MOVWF	PWM
;*--- Controle dos ares-condicionados ---*
	BCF		AR1					;Todos os ares-condicionados est�o desligados
	BCF		AR2					
	BCF		AR3
	BCF		AR4

	RETURN						; os outros 4 bits (MSB) de PORTD

POT_BAIXA				;Se a temperatura est� entre 20�C e 25�C:
;*--- Controle da pot�ncia do conjunto de ventiladores ---*
	BANK0
	MOVLW	77					;Pot�ncia de 30% no conjunto de ventiladores
	MOVWF	PWM
;*--- Controle dos ares-condicionados ---*	
	BSF		AR1					;O ar-condicionado 1 ser� ligado
	BCF		AR2
	BCF		AR3
	BCF		AR4
	
	RETURN
	
POT_ALTA				;Se a temperatura est� entre 25�C e 30�C:
;*--- Controle da pot�ncia do conjunto de ventiladores ---*
	BANK0
	MOVLW	192					;Pot�ncia de 75% no conjunto de ventiladores
	MOVWF	PWM
;*--- Controle dos ares-condicionados ---*
	BSF		AR1					;Os ares-condicionado 1 e 2 ser�o acionados
	BSF		AR2
	BCF		AR3
	BCF		AR4
	RETURN

POT_MAXIMA				;Se a temperatura est� maior que 30�C:
;*--- Controle da pot�ncia do conjunto de ventiladores ---*
	BANK0
	MOVLW	230					;Pot�ncia de 90% no conjunto de ventiladores
	MOVWF	PWM
;*--- Controle dos ares-condicionados ---*
	BSF		AR1					;Todos os ares-condicionados ser�o ligados
	BSF		AR2
	BSF		AR3
	BSF		AR4

	RETURN

;*************************************************** 
;*       	     ROTINA DE DELAY (us)	           *                   
;***************************************************

DELAY_US			;Rotina implementada para o tempo de adequa��o do capacitor 
	BANK0			;na troca de canal 
	MOVWF	AUX_TEMP		;Carrega o valor inicial para AUX_TEMP
	
	DECFSZ	AUX_TEMP, F		;Decrementa��o da vari�vel para o delay
	GOTO	$-1				;Ap�s chegar em zero, sai da rotina de delay
	
	RETURN


;*************************************************** 
;*       	     ROTINA DE DELAY (ms)	           *                   
;***************************************************

						;Rotina de gera��o de delay a partir do contador Timer0 que conta os ciclos de um oscilador externo
DELAY_TA
	BANK0
    CLRF    TMR0			;Limpa o registro do contador Timer0
 	BCF 	FLAG_TMR0		;Limpa o flag de estouro do Timer0
 	MOVLW	TA
	MOVWF 	TMR0			;Move o valor do acumulador para TMR0

	BTFSS 	DELAY_OK		;A contagem do delay terminou?
	GOTO 	$-1				;Caso n�o tenha terminado, volta pra instru��o anterior
							;Aguardando at� que TFLAG estoure (termine a contagem)
	RETURN					;Retorna o desvio de chamada

;*************************************************** 
;*       	  	 ROTINA DESATIVA TUDO		       *                   
;***************************************************
DESATIVA_TUDO
					;Quando o sensor de presen�a acusa que n�o h� ningu�m,
					;todas as sa�das (ventilador, ares-condicionados e lumin�rias) s�o desativadas
	CLRF	PORTB
	CLRF	PORTC
	CLRF	PORTD
		
	BCF		LIGADO
		
	MOVLW	0
	MOVWF	PWM
		
	RETURN
	
;************************************************* 
;*          INICIALIZA��O DAS VARI�VEIS          *                   
;*************************************************
INIC_VAR					;Inicializa as vari�veis
	CLRF	PORTA			;Zera PORTA A
	CLRF    PORTB			;Zera PORTA B
	CLRF	PORTC			;Zera PORTA C
	CLRF	PORTD			;Zera PORTA D
	
	CLRF	TEMPERATURA_VAR	;Zera o valor das vari�veis 
	CLRF	LUMINOSIDADE_VAR	

	RETURN

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                     IN�CIO DO PROGRAMA                                  *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;Configura��o de opera��o do microcontrolador
INICIO
	BANK1					;Altera para o Banco 1 da mem�ria de dados
	MOVLW	B'00011011'		;Configura PORTA como entrada ou sa�da
	MOVWF	TRISA			;IN: RA0, RA1, RA4.	OUT: RA2, RA3, RA5, RA6, RA7
		
	MOVLW	B'00000001'		;Configura PORTB como entrada ou sa�da
	MOVWF	TRISB			;IN: RB0.	OUT: RB1, RB2, RB3, RB4, RB5, RB6, RB7							

	MOVLW	B'00000000'		;Configura PORTB como entrada ou sa�da
	MOVWF	TRISC			;OUT: RC0, RC1, RC2, RC3, RC4, RC5, RC6, RC7	

	MOVLW	B'00000000'
	MOVWF	TRISD			;OUT: RD0, RD1, RD2, RD3, RD4, RD5, RD6, RD7	
	
	MOVLW	B'11101000'		;OPTION_REG: RBPU|INTEDG|T0CS|T0SE|PSA|PS2|PS1|PS0
	MOVWF	OPTION_REG 		;habilita pull-ups portb|fonte de clock ser� RA4/T0CKI|sem prescaler pra TMR0|0|0|0
	

	MOVLW	B'11110000'		;Habilita a interrup��o global, de perif�ricos, do Timer0, e interrup��o externa de RB0
	MOVWF	INTCON

	MOVLW	B'01000000'		;Habilita a interrup��o do conversor A/D
	MOVWF	PIE1
	
	MOVLW	B'10000101'		;Seleciona RA0 e RA1 como portas anal�gicas
	MOVWF	ADCON1			;bit 7 (ADFM): A/D Result format select bit: 1 = Right justified. Six (6) Most Significant bits of ADRESH are read as �0�.
							;bit 6 (ADCS2): A/D Conversion Clock Select bit 	
							;Bits 3-0: Configura��o das portas como anal�gico ou digital
							;		   0101 -> AN0 e AN1 definidas como portas anal�gicas, o restante, digital. AN3-> Vref+
	BANK0					;Altera para o Banco 0 da mem�ria de dados
	
	BSF		T2CON, TMR2ON	;Ativa o TMR2 que � a base de tempo do sinal gerada para o PWM

	MOVLW	B'11000001' 	;Ajuste das configura��es do conversor A/D
	MOVWF	ADCON0			;Bits 7-6 -> Sele��o do clock RC interno para convers�o
							;Bits 5-3 -> Sele��o do canal que ser� usado para convers�o A/D
							;Bit 2 -> Status da convers�o 
							
	MOVLW	B'00001100'		;Configura��o do m�dulo CCP1
	MOVWF	CCP1CON			;Bit 3-0: CCPxM3:CCPxM0: CCPx Mode Select bits -> 11xx = Modo PWM

	CALL	INIC_VAR		;Coloca os valores iniciais das vari�veis

;************************************************* 
;*               ROTINA PRINCIPAL                *                   
;*************************************************
MAIN_LOOP
	BTFSC	PRESENCA			;Testa se o sensor de presen�a est� ativado 
	GOTO	INICIO_CONTROLE		;Se tiver, come�a o in�cio da leitura dos sensores e controle

	CALL	DESATIVA_TUDO		;Se n�o tiver, desativa todas as sa�das		
	SLEEP						; O MCU estar� em Sleep, at� que o sensor de presen�a
	NOP							; verifique que h� algu�m no ambiente						
									
INICIO_CONTROLE
	BSF		LIGADO					;Aciona o LED avisando que o sistema est� ligado

	CALL	LER_TEMPERATURA			;Faz a leitura do sensor de temperatura
	CALL	CONTROLE_TEMPERATURA	;A partir da leitura, realiza o controle de temperatura
									;Fazendo controle do acionamento do conjunto de ventiladores 
									;e ares-condicionados
									
	CALL	LER_LUMINOSIDADE		;Faz a leitura do sensor de luminosidade
	CALL	CONTROLE_LUMINOSIDADE	;A partir da leitura, realiza o controle de temperatura
									;Fazendo controle do acionamento das lumin�rias
									
	CALL	DELAY_TA				;Depois de lidos os sensores, espera-se um tempo para a nova medi��o
									;j� que as vari�veis mudam lentamente
	GOTO	MAIN_LOOP

;XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
;X                FIM DO PROGRAMA                X                   
;XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
	END