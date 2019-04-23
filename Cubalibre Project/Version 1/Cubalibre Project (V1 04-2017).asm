;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
;*        T�tulo: M�quina preparadora de Cuba Libre (Exerc�cio 1)	     					           *
;* 																									   *
;* 		Disciplina: Microcomputadores				Semestre: 2017.1								   *
;* 		Professor:	Mauro Rodrigues dos Santos														   *                              
;*		                                                         								 	   *
;*      Desenvolvido por:											                                   *
;*   	=> 	Guilherme de Souza Bastos                                                                  *
;*   	=> 	Karl Vandesman de Matos Sousa															   *
;*										   									                           *
;*      VERS�O: 1.0                            		DATA:22/04/2017                                    *
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
; As m�quinas devem ser reabastecidas ap�s a prepara��o de N Cubas Libres.
                                                                                                                                    
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

	#DEFINE	TFLAG	INTCON,	T0IF		;Flag que sinaliza estouro do Timer
;*************************************************** 
;*       			 VARI�VEIS                     *                   
;*************************************************** 
;Defini��o do bloco de vari�veis 
	CBLOCK 0x20				;Endere�o inicial da mem�ria do usu�rio						
		AUX_PULSOS			;Vari�vel auxiliar para contagem do n�mero de pulsos para a m�quina M2
		N					;Quantidade de bebidas que ainda podem ser feitas
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

	#DEFINE		PARTIDA 	PORTA, RA5  	;Bot�o de partida (ligamento da m�quina e prepara��o das vari�veis)
	#DEFINE 	PREPARAR	PORTB, RB3	 	;Bot�o para come�ar preparamento da bebida
	#DEFINE		S			PORTB, RB0		;Sinal enviado por M4 avisando que j� escoou 250ml de Coca-Cola
	#DEFINE		OSC			PORTA, RA4		;Oscilador externo (necessidade de delay muito grande)

;*************************************************** 
;*                     SA�DAS                      *                   
;*************************************************** 
; DEFINI��O DE TODOS OS PINOS QUE SER�O UTILIZADOS COMO SA�DA

	#DEFINE 	M1			PORTB, RB4		;M�quina 1 (fornece dose de rum)
	#DEFINE 	M2			PORTB, RB5		;M�quina 2 (fornece um cubo de gelo)
	#DEFINE 	M3			PORTB, RB6		;M�quina 3 (fornece uma fatia de lim�o)
	#DEFINE 	M4			PORTB, RB7		;M�quina 4 (fornece 250ml de Coca-Cola e envia sinal de sa�da S=1)
	
	#DEFINE 	PREPARANDO	PORTB, RB1		;Sinaliza que est� em andamento a prepara��o da bebida
	#DEFINE 	FIM			PORTB, RB2		;Sinaliza t�rmino do preparo da bebida
		
	#DEFINE 	D1	PORTA, RA0				;4 Segmentos para acionamento do Display de 7 segmentos, que
	#DEFINE 	D2	PORTA, RA1				;j� possui decodificador interno
	#DEFINE 	D3	PORTA, RA2			
	#DEFINE 	D4	PORTA, RA3	

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                         VETOR DE RESET                                  *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

	ORG		0x00	    	;Endere�o inicial de processamento
	GOTO	INICIO

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                  DEFINI��O DE ROTINAS E SUB-ROTINAS                     *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

;*************************************************** 
;*        ROTINA DE VERIFICA��O DE MATERIAL        *                   
;*************************************************** 
VERIFICAR_MATERIAL
	MOVF	N, W		;Move o valor de N para o acumulador W
	BTFSC	STATUS, Z	;Caso o valor de N seja zero, o sinalizador Z ser� setado
	GOTO	$-2		
	RETURN				;Retorno da rotina de chamada

;*************************************************** 
;*        ROTINA DE ACIONAMENTO DE M�QUINAS        *                   
;***************************************************
ACIONA_MAQ
	BSF		M1				;Aciona a M�quina M1
	CALL	DELAY_TA		;Chama delay para manter acionamento de M1
	BCF		M1				;Para o acionamento de M1
	CALL	DELAY_TA 		;Chama delay

	MOVLW	4				;Atribuindo valor 4 para AUX_PULSOS
	MOVWF	AUX_PULSOS		;Para determinar 4 pulsos de acionamento para M2
	BSF		M2				;Aciona a M�quina M2
	CALL	DELAY_TA		;Chama delay para manter acionamento de M2
	BCF		M2				;Para o acionamento de M2
	CALL	DELAY_TA		;Chama delay
	DECFSZ	AUX_PULSOS		;Decrementa AUX_PULSOS e testa se � zero
	GOTO	$-5				;Caso AUX_PULSOS>0, volta 5 instru��es onde se 
							;iniciou acionamento de M2

	BSF		M3				;Aciona a M�quina M3	
	CALL	DELAY_TA		;Chama delay para manter acionamento de M3
	BCF		M3				;Para o acionamento de M3
	CALL	DELAY_TA		;Chama o delay

	BSF		M4				;Aciona a M�quina M4
	CALL	DELAY_TA		;Chama delay para manter acionamento de M4
	BTFSS	S				;Testa o sinal S da m�quina 4 que sinaliza
	GOTO	$-1				;t�rmino do despejo de Coca-Cola
	BCF		M4
	RETURN					;Retorno da rotina de chamada	

;*************************************************** 
;*       	     ROTINA DE DELAY		           *                   
;***************************************************
DELAY_TA					;Rotina de gera��o de delay a partir do contador Timer0 
    CLRF    TMR0			;Limpa o registro do contador Timer0
 	BCF 	TFLAG			;Limpa o flag de estouro do Timer0
	MOVLW 	TA				;Move o valor do delay (TA)
	MOVWF 	TMR0			;Move o valor de delay de TA para TMR0

	BTFSS 	TFLAG			;A contagem do delay terminou?
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

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                     IN�CIO DO PROGRAMA                                  *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;Configura��o de opera��o do microcontrolador
INICIO
	BANK1					;Altera para o Banco 1 da mem�ria de dados
	MOVLW	B'00110000'		;Configura PORTA como entrada ou sa�da
	MOVWF	TRISA			;IN: RA4, RA5.	OUT: RA0, RA1, RA2, RA3, RA6 RA7
						
	MOVLW	B'00001001'		;Configura PORTB como entrada ou sa�da
	MOVWF	TRISB			;IN: RB0, RB3.	OUT: RB1, RB2, RB4, RB5, RB6, RB7							
	
	MOVLW	B'11101000'		;OPTION_REG: RBPU|INTEDG|T0CS|T0SE|PSA|PS2|PS1|PS0
	MOVWF	OPTION_REG 		;habilita pull-ups portb|fonte de clock ser� RA4/T0CKI|sem prescaler pra TMR0|0|0|0

	MOVLW	B'00001000' 	;Utilizar cristal interno de 4MHz
	MOVWF	PCON

	MOVLW	0				;Desabilitar todas as interrup��es
	MOVWF	INTCON			
	
	BANK0					;Altera para o Banco 0 da mem�ria de dados
	
	MOVLW	B'00000111'
	MOVWF	CMCON			;Desabilitar as entradas anal�gicas e colocar digitais

;************************************************* 
;*          INICIALIZA��O DAS VARI�VEIS          *                   
;*************************************************
INIC_VAR					;Inicializa as vari�veis
	CLRF	PORTA			;Zera PORTA A
	CLRF    PORTB			;Zera PORTA B
	CLRF	AUX_PULSOS		;Zera Vari�vel Auxiliar
	MOVLW	N_INIC			;Valor inicial da quantidade 	
	MOVWF	N				;de bebidas que podem ser preparadas

LIGAR					
	BTFSS	PARTIDA			;Testa o pino PARTIDA
	GOTO	$-1				;Aguarda PARTIDA=1 para entrar na rotina principal

;************************************************* 
;*               ROTINA PRINCIPAL                *                   
;*************************************************
MAIN_LOOP 
	CALL 	DISPLAY			;Aciona o Display com o valor de N
	CALL	VERIFICAR_MATERIAL	;Verifica se h� material suficienta para 	
								;prepara��o da bebida
	BTFSS	PREPARAR		;Se PREPARAR for pressionado, a bebida come�a a ser feita (ativo em 1)
	GOTO	$-1				;Aguarda PREPARAR=1 para preparar a bebida
	CALL	DELAY_TA	

	BCF		FIM				;Apaga LED FIM
	BSF		PREPARANDO		;Acende LED PREPARANDO
	DECF	N, 1			;Decrementa valor de N, e o destino � 1 (o pr�prio registro N) 
	CALL 	DISPLAY			;Aciona o Display com o valor de N
	CALL	DELAY_TA

	CALL	ACIONA_MAQ		;Chama rotina para acionamento das m�quinas
	
	BCF		PREPARANDO		;Fim da prepara��o da bebida, LED PREPARANDO se apaga
	BSF		FIM				;e LED FIM acende
	CALL	DELAY_TA		;Chama Delay

	GOTO	MAIN_LOOP		;Retorna para o come�o da rotina MAIN_LOOP

;XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
;X                FIM DO PROGRAMA                X                   
;XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
	END