    ;programa k controla el llenado de un tanke princial con dos subtankes
    ;el cual el tanke A debe llenar con 60% y el tkB con 40%
    ;con un tamaño de 30cm de alto se debera calcular sus respectivos porcentajes
    ;es decir 50% de 30cm es 15cm y su respectivo llenado del 60% de tkA es 9 y el 40% del tkB es 6
    ;debera tener dos pulsadores uno para asc y otro desc cada 5%
    ;pulsador de START y STOP y un motor para mover cuando se llegue el agua al 60%
    
    list p=16F88
	#include P16F88.inc
	__CONFIG _CONFIG1, _CPD_OFF & _CP_OFF & _DEBUG_OFF & _LVP_OFF & _MCLR_ON & _PWRTE_ON & _WDT_OFF &_WRT_PROTECT_OFF & _XT_OSC & _BODEN_OFF
;**** Definicion de variables ****

	#define CLK PORTB,0
	#define DS PORTB,1
	#define ST PORTB,2
	
	#define PA PORTA,0
	#define PD PORTA,1
	
	#define START PORTA,2
	#define STOP PORTB,7
	
	#DEFINE TRIGGER PORTA,3
    #DEFINE ECHO	PORTA,4
    
    #DEFINE VALV1   PORTB,3
    #DEFINE VALV2	PORTB,4
    #DEFINE VALV3	PORTB,5
    #DEFINE MOTOR	PORTB,6 

	cblock 0x20
		Unidad, Decena,Centena,Contador, Aux, Dato, Inc_Dec, Valor_CM, Valor_A, Valor_B, Display_3
		Multiplicando, Multiplicador, Dividendo, Divisor, Resultado ,Unid, Var, Var2, Var3, Var4
		Cont, W_Temp, STATUS_Temp, VAR_DISTANCIA, DIST_MAX,VAR_DIST2,VAR_DIST3,Prueba
	endc

;**** Inicio  del Micro ****
	org  0x00    ; Aqui comienza el micro.-
	goto  Inicio   ; Salto a inicio de mi programa.-
	ORG	    4
    GOTO   INT_TMR0
	org  0x05    ; Origen del código de tabla.-

; Tabla
TABLA      ; retlw b'gfedcba'  para display cátodo comun
	addwf  PCL,1    ; Se incrementa el contador del programa.-
	retlw  b'0111111'  ; 0
	retlw  b'0000110'  ; 1
	retlw  b'1011011'  ; 2
    retlw  b'1001111'  ; 3
    retlw  b'1100110'  ; 4
    retlw  b'1101101'  ; 5
    retlw  b'1111101'  ; 6
    retlw  b'0000111'  ; 7
    retlw  b'1111111'  ; 8
    retlw  b'1101111'  ; 9

;**** Programa principal ****
;**** Configuración de puertos ****
Inicio
	banksel TRISA   ;Pasamos de Banco 0 a Banco 1
	movlw 0x80
	movwf TRISB
    movlw 0x17
	movwf TRISA
	clrf ANSEL   ;Pines digitales.
	
	;**** Configuración de Interrupcion **** 
	movlw 0x80     ; preescaler de 2
	movwf OPTION_REG
	movlw 0xA0      
	movwf INTCON
    banksel PORTA
    clrf PORTB
    bsf VALV1
    bsf VALV2
    bsf VALV3
    bsf MOTOR
    
    movlw .233     ;Timer0 se desborda cada 58us
	movwf TMR0
    
	clrf Unidad
    clrf Decena
    clrf Centena
    clrf Var3        ; variable ke detecta ke se pulso START
    clrf Var2
    clrf Var
    clrf Valor_CM
    clrf VAR_DISTANCIA
    clrf VAR_DIST3
    
      movlw .50      ;50 es el minimo
      movwf Inc_Dec 
      call Operaciones
      call Imprimir 
    
;****  Pulsadores ****
Bucle
    call Button_UP
	call Button_DWN
	call Button_START
	;call Distancia
	;goto Bucle	
	btfsc Var3,0	;espera k se presione start para k salte al siguiente proceso
	goto Bucle2	
	goto Bucle
	
;*****************************************		
Bucle2
    bcf VALV1           ;enciende valvula de tanke A 60% 
    clrf Var3   
Buc  
    call Button_STOP
    call Distancia
    call Button_STOP  
    call Comparar
    movf VAR_DIST3,W    ; Valor_CM - Distancia 
    subwf Valor_CM,W      ;C=0 si el resultado de la resta es negativo
    btfsc STATUS,C        ;c=1 si el resultado de la resta es positivo
    goto Buc
    call Button_STOP    
    clrf Var3
    bsf VALV1
    bsf VALV2
    bsf MOTOR
    call Evacuar
    goto Bucle
    
  Comparar              ;rutina que detecta si ya llego el 60% 
    movf VAR_DIST3,W    ;Valor_A tiene la cantidad del 60%
    subwf Valor_A,W
    btfsc STATUS,C
    goto Comp_
    call Button_STOP
    bsf VALV1
    bcf VALV2
    bcf MOTOR
    return
 Comp_
    bcf VALV1
    return   
    
  Evacuar
    bsf VALV2
    bsf MOTOR
    bcf VALV3
    call Button_STOP
    call Distancia
    movlw .0
    subwf VAR_DIST3,W
    btfss STATUS,Z      ;C=0 si la resta da negativo
    goto Evacuar
    bsf VALV3
    bsf VALV2
    bsf MOTOR
    bSf VALV3
  return  
;**********************************************************    	
Distancia
    CLRF    VAR_DISTANCIA
    BSF	    TRIGGER
    movlw .1
	call Delay_ms
    BCF	    TRIGGER
ECHO_ES_1
    BTFSS   ECHO
    GOTO    ECHO_ES_1
    MOVLW   .233
    MOVWF   TMR0
    movlw 0xA0      
	movwf INTCON	;HABILITAR A QUE PUEDAN HABER INTERRUPCIONES
ECHO_ES_0
    BTFSC   ECHO
    GOTO    ECHO_ES_0
    CLRF    INTCON	;DETENER LAS INT.  
    movf Valor_A,W   ;IMPRIME EL VALOR_A
    call BIN_BCD 
    movf Decena,W      
    call TABLA
    call Envia_Ser    
    movf Unidad,W
    call TABLA
    call Envia_Ser
  
    movf Valor_B,W   ;IMPRIME EL VALOR_B
    call BIN_BCD 
    movf Decena,W         
    call TABLA
    call Envia_Ser    
    movf Unidad,W
    call TABLA
    call Envia_Ser
    
    movf Valor_CM,W   ;IMPRIME EL VALOR_CM 
    call BIN_BCD
    movf Decena,W        
    call TABLA
    call Envia_Ser    
    movf Unidad,W
    call TABLA
    call Envia_Ser
    
    movlw .34               ; tamaño del tankee(deposito)
    movwf VAR_DIST2         ; se resta porke el sensor esta arriba
    movf VAR_DISTANCIA,W    ;y se lee al revez la distancia
    subwf VAR_DIST2,W       ;20-X= +     
    btfss STATUS,C           ;C=0 si la resta da negativo    si el la medida falla es
    goto  Distancia          ;C=1 si la resta da positivo    un valor mayor a tamaño del tanke
    movwf VAR_DIST3          ;guarda el valor correcto
    
    ;movf VAR_DISTANCIA,W 
    call BIN_BCD             ;separamos el valor en unidad decena y centena
    movf Centena,W     
    call TABLA
    call Envia_Ser    
    movf Decena,W
    call TABLA
    call Envia_Ser    
    movf Unidad,W       
    call TABLA
    call Envia_Ser            
    bsf PORTB,2
    call Retardo_500ms        ;retardo para ke se lea cada .5s
    return     
	
;**** Interrupcion *****
INT_TMR0
	movwf W_Temp  ; Copiamos W a un registro Temporario.
    swapf STATUS,0  ;Invertimos los nibles del registro STATUS.
    movwf STATUS_Temp  ; Guardamos STATUS en un registro 
	movlw .233
	movwf TMR0	
	MOVLW   .1
    ADDWF   VAR_DISTANCIA,F  ;se suma en una unidad la variable 
    MOVLW   DIST_MAX 
    BTFSC   STATUS,C         ;
    MOVWF   VAR_DISTANCIA	
	bcf INTCON,2	
	swapf STATUS_Temp,0 ; Invertimos lo nibles de STATUS_Temp.    
	movwf STATUS
	swapf W_Temp,1  ; Invertimos los nibles y lo guardamos en el mismo registro.
    swapf W_Temp,0  
	retfie		
	
;***********************************************************	
Operaciones   
   movlw .86          
   subwf Inc_Dec,W   
   btfss STATUS,C     ; si la resta se desbordo      C=0 si la resta es negativo
   goto No_es_Mayor   ;no se desbordo                C=1 si la resta es positivo
   movlw .1           
   movwf Var          
   movlw .10          ;divide 90/10= 09   95/10=09  100/10=10
    movwf Divisor
    movf Inc_Dec,W
    movwf Dividendo    
    call Dividir
    movwf Resultado
    movlw .94          
    subwf Inc_Dec,W    ;94-90=4 C=0   95-94= -1(254)  C=1
    btfss STATUS,C     ;salta si la operacion rsulta C=1
    goto $+8           ;no se desborno el C=0  se va a dividir 90/10=09
    btfsc Var2,0       ;pregunta si ya pasamos por 95
    goto mayor_100
    movlw .1 
    movwf Var2         
    movlw .28          
    movwf Resultado    ;y directamente guarda el valor en valor_CM
    goto ValorX      
    movf Resultado,W   ;aun estamos en 90
    goto $+9
mayor_100              ;rutina kdivide el 100/10=10
    movlw .10 
    movwf Divisor
    movf Inc_Dec,W
    movwf Dividendo    
    call Dividir 
    movf Resultado,W
    goto $+2
     
 No_es_Mayor           ;rutina k multiplica para la medida de 30cm
    movf Inc_Dec,W     ;MULTIPLICA DISPLAY_CM    
    movwf Multiplicando     ;50%x30Cm/100%=15Cm   ;55%x30Cm/100%=16.5Cm   ;60%x30Cm/100%=18Cm
    movlw .3                ;65%x30Cm/100%=19.5Cm   ;70%x30Cm/100%=21Cm   ;75%x30Cm/100%=22.5Cm
    movwf Multiplicador     ;80%x30Cm/100%=24Cm   ;85%x30Cm/100%=25.5Cm   ;90%x30Cm/100%=27Cm
    call Multiplicar        ;95%x30Cm/100%=28.5Cm   ;100%x30Cm/100%=30Cm   
    movwf Resultado         ;y todo se guarda en la variable Resultado
    
    btfss Var,0              ;si ya estamos en 90% a 95%
    goto  No_Mayor  
    movlw .26
    subwf Resultado,W
    btfss STATUS,C
    goto No_Mayor
    movf Resultado,W
    goto $+7
No_Mayor    
    movlw .10 
    movwf Divisor
    movf Resultado,W
    movwf Dividendo    
    call Dividir 
    movf Resultado,W
 ValorX
    movwf Valor_CM
    movwf Valor_B
    
    movf Resultado,W    ;MULTIPLICA P/OBTENER VALOR_A   60%
    movwf Multiplicando  ;rutina k mutiplica el 60% del TKA
    movlw .6               ;15Cm x 60%/10 = 09   ;16Cm x 60%/10 = 09   ;18Cm x 60%/10 = 10 
    movwf Multiplicador    ;19Cm x 60%/10 = 11   ;21Cm x 60%/10 = 12   ;22Cm x 60%/10 = 13 
    call Multiplicar       ;24Cm x 60%/10 = 14   ;25Cm x 60%/10 = 15   ;27Cm x 60%/10 = 16 
                           ;28Cm x 60%/10 = 16   ;30Cm x 60%/10 = 18   
    movlw .10 
    movwf Divisor
    movf Resultado,W
    movwf Dividendo    
    call Dividir 
    movf Resultado,W
    movwf Valor_A
    
    movf Valor_A,W     ;RESTA PARA OBTENR EL VALOR_B   40%
    subwf Valor_B,F    ;rutina k calcula el 40% del TKB   solo la resta 
    return             ;15Cm - 09= 06   ;16Cm - 09= 07   ;18Cm - 10= 08  ;19Cm - 11= 08  ;21Cm - 12= 09
     ;22Cm - 13= 09    ;24Cm - 14= 10   ;25Cm - 15= 10   ;27Cm - 16= 11   ;28Cm - 16= 12  ;30Cm - 18= 12 
    ;*******************************************************+
    
BIN_BCD
	clrf	Centena		; Carga los registros con el resultado inicial.
	clrf	Decena		; En principio las centenas y decenas a cero.
	movwf	Unidad		; Se carga el número binario a convertir.
Resta10
	movlw	.10			; A las unidades se les va restando 10 en cada
	subwf	Unidad,W		; pasada. (W)=(BCD_Unidades) -10.
	btfss	STATUS,C		; ¿C = 1?, ¿(W) positivo?, ¿(BCD_Unidades)>=10?
	goto 	_Fin		; No, es menor de 10. Se acabó.
IncrementaDecenas
	movwf	Unidad		; Recupera lo que queda por restar.
	incf	Decena,F		; Incrementa las decenas y comprueba si ha llegado
	movlw	.10			; a 10. Lo hace mediante una resta.
	subwf	Decena,W		; (W)=(BCD_Decenas)-10).
	btfss	STATUS,C		; ¿C = 1?, ¿(W) positivo?, ¿(BCD_Decenas)>=10?
	goto	Resta10		; No. Vuelve a dar otra pasada, restándole 10 a
IncrementaCentenas			; las unidades.
	clrf	Decena		; Pone a cero las decenas 
	incf	Centena,F		; e incrementa las centenas.
	goto	Resta10		; Otra pasada: Resta 10 al número a convertir.
_Fin
	return				; Vuelve al programa principal.
	
    
 Imprimir     
    movf Valor_A,W   ;IMPRIME EL VALOR_A
    call BIN_BCD 
    movf Decena,W      
    call TABLA
    call Envia_Ser    
    movf Unidad,W
    call TABLA
    call Envia_Ser
  
    movf Valor_B,W   ;IMPRIME EL VALOR_B
    call BIN_BCD
    movf Decena,W         
    call TABLA
    call Envia_Ser    
    movf Unidad,W
    call TABLA
    call Envia_Ser
    
    movf Valor_CM,W   ;IMPRIME EL VALOR_CM 
    call BIN_BCD
    movf Decena,W        
    call TABLA
    call Envia_Ser    
    movf Unidad,W
    call TABLA
    call Envia_Ser
    
    movf Inc_Dec,W     ;DIVIDE DISPLAY_3
    call BIN_BCD 
    movf Centena,W  
    call TABLA
    call Envia_Ser    
    movf Decena,W
    call TABLA
    call Envia_Ser     
    movf Unidad,W      
    call TABLA
    call Envia_Ser    
    movlw .100
    subwf Inc_Dec,W
    btfss STATUS,Z
    goto $+3
    clrf Var
    clrf Var2    
    bsf PORTB,2    
    return       

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;; MULTIPLICAR ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;      
  Multiplicar 
      clrf Resultado
  Loopx    
      movf Multiplicando,W
      addwf Resultado,F 
      decfsz Multiplicador
      goto Loopx
      movf Resultado,W
      return  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; DIVIDIR ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;      
  Dividir
      clrf Resultado
  Loopy   
      movf Divisor,W
      subwf Dividendo,F
      btfsc STATUS,C     ;VERIFICAMOS EL ACARREO
      goto Loopz          ;
      movf Resultado,W
      return      
  Loopz
      incf Resultado,F
      goto Loopy 

;**** UP *****
Button_UP
	btfsc PA    
    return
	movlw .20
	call Delay_ms
	btfsc PA    
    return      
	btfss PA    
    goto $-1    
    movlw .20
	call Delay_ms
	btfss PA    
	goto $-5    
    call Incr
    call Operaciones
    call Imprimir
	return

;**** DWN *****
Button_DWN
	btfsc PD    
    return      -
    movlw .20
	call Delay_ms
	btfsc PD    
    return      
	btfss PD    
    goto $-1    
    movlw .20
	call Delay_ms
	btfss PD    
	goto $-5   
    clrf Var
    call Decr
    call Operaciones
    call Imprimir
	return
	
	;****  START *****
Button_START
	btfsc START    ; Testeamos si esta a 1 lógico.-
    return
	movlw .20
	call Delay_ms
	btfsc START    ; Testeamos nuevamente.-
    return         ; Falsa Alarma, retornamos
	btfss START    ; Testeamos si esta a 0 lógico.-
    goto $-1       ; No, seguimos testeando si soltamos.-
    movlw .20
	call Delay_ms
	btfss START    ; Testeamos nuevamente.-
	goto $-5       ; No, Falsa alarma, volvemos
	call Distancia
	movlw .1
	movwf Var3
	return
	
	;**** STOP *****
Button_STOP
	btfsc STOP   
    return
	movlw .20
	call Delay_ms
	btfsc STOP   
    return         
	btfss STOP    
    goto $-1       
    movlw .20
	call Delay_ms
	btfss STOP    
	goto $-5       
	bsf VALV1
    bsf VALV2
    bsf MOTOR
    bSf VALV3
	call Button_START
	btfss Var3,0
	goto $-2
	clrf Var3
	return
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;      
   Incr      
      movlw  .5            ;aumenta de 5 en 5
      addwf Inc_Dec,F
      movlw .105           ;If INC_DEC > 100 Then INC_DEC=50
      subwf Inc_Dec,W      ;si la suma ecxede de 100
      btfss STATUS,Z       ;sise pasa de 100 regresamos a 50
      return
      movlw .50  ;50
      movwf Inc_Dec
      return
   Decr  
      movlw  .5
      subwf Inc_Dec,F
      movlw  .45   ;.45      ;If INC_DEC < 50 Then INC_DEC=100
      subwf Inc_Dec,W      ;se resta con 45 porke solo es asta 50
      btfss STATUS,Z       ;si ees menor k 45 se pasa a 100
      return
      movlw D'100'         ;    
      movwf Inc_Dec
      return 
      
Envia_Ser
    bcf PORTB,2
    movwf Dato
    movlw .8
    movwf Aux
    btfsc Dato,7
    goto $+3
    bcf DS
    goto $+2
    bsf DS
    bcf CLK
    rlf Dato,1
    bsf CLK
    decfsz Aux
    goto $-9
    ;bsf PORTB,2
    return

	include <Delay_ms.inc>
	include RETARDOS.INC
    end


