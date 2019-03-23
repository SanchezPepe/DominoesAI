/**
Al inicio el sistema recibe:
    1.- Las fichas asignadas ------------ LISTO
    2.- Quién tira primero - quién tuvo la mula más grande  ----- LISTO. Se indica por meido de turno(X). 
       X = 1, es nuestro turno. X = 0, es turno del contrincante. Por default está en 1 al inicio del juego. 

Funciones a implementar:
    1.- Tomar del pozo (robar) ---------- LISTO
    2.- Tirar ficha
    3.- Tirar ficha rival -------------- LISTO
    4.- Función eurística (28-Tiradas-Mías= Fichas del Rival y pozo)
        a) Cuando el rival tome del pozo, guardar las fichas que no tiene
        b) Deshacerse lo más rápido posible de las mulas
        c) Mantener variada la mano de fichas
    5.- Imprimir tablero ------------  LISTO
    

    Links
    List sort: https://stackoverflow.com/questions/8429479/sorting-a-list-in-prolog
**/
:- ensure_loaded(fichas).
:- dynamic posibles/1.

tirar([3,4]).
der(2).
izq(3).

mano2([[1,3],[4,0],[1,1],[5,3],[0,0]]).
posibles([]).

numeros([7,7,7,7,7,7,7]).

/* Aqui le cargamos las fichas que nos reparten al inicio del juego. 
Se tiene que llamar "inicio." e ingresar las 7 fichas, y posteriormente poner "fin.". */

repite.
repite:-
    repite.

inicio():-
    write("Ingresa las 7 fichas iniciales. "),nl,
    repite,
    read(Ficha), 
    mano(X),   
    append(X,[Ficha],Y),
    retract(mano(X)),
    assert(mano(Y)),
    retract(desconocidas(Ficha)),
    Ficha==fin.

roba:-
   pozo(0),
   pasa.
roba:-
    write("Dame la ficha que robo. "),nl,
    read(Ficha),
    assert(mano(Ficha)),
    retract(desconocidas(Ficha)).
pasa:-
    assert(turno(0)),
    retractall(turno(1)).

reverse([],Z,Z).
reverse([H|T],Z,Acc):-
    reverse(T,Z,[H|Acc]).

extremoIzq():-
    tablero([H|_]),
    extremoIzq(H).
extremoIzq([H|_]):-
    retractall(extremoIzquierdo(_)),
    assert(extremoIzquierdo(H)).

extremoDer():-
    tablero([_|T]),
    reverse(T,X,[]),
    extremoDer(X),!.
extremoDer([H|_]):-
    reverse(H,X,[]),
    is_list(X),
    extremoDer(X),!.
extremoDer([H|_]):-
    retractall(extremoDerecho(_)),
    assert(extremoDerecho(H)).


tiroOponente:-
    write("¿El oponente tiró alguna ficha? si/no"),nl,
    read(Resp),
    Resp==si,
    write("¿Qué ficha tiró el oponente?"),nl,
    read(Ficha),
    retract(desconocidas(Ficha)),
    tablero(X),
    append(X,[Ficha],Y),
    retract(tablero(X)),
    assert(tablero(Y)),
    extremoDer,
    extremoIzq.

/**
 * Regla que decrementa la lista que guarda cuántas fichas quedan de cada grupo, se utliza en la 
 * función eurística para dar información al sistema al momento de utlizar la función eurística.
 **/
decrementa(X):-
    numeros(Y),
    % Obtiene de la lista
    nth0(X,Y,Z),
    % Quita de la lista
    nth1(X,Y, _, W),
    A is Z-1,
    % Inserta en la lsita
    nth0(X, B, A, W),
    retract(numeros(Y)),
    assert(numeros(B)).

/**
 * Regla que busca las fichas posibles para tirar en cada jugada dependiendo del estado actual del tablero.
 * Regresa una sublista posibles([]) de la mano actual
 **/
/**
movimientosPosibles([], _).
movimientosPosibles([H|_], Z):-
    der(Y),
    izq(X),
    (member(X, H) ; member(Y,H)),
    append(Z, [H], R),
    movimientosPosibles(T, R),
    Z = R, !.
movimientosPosibles([_|T], Z):-
    movimientosPosibles(T, Z), !.

mano3([[3,2], [6,2], [4,7], [3,0]]).
m3([4,2,3,3,3,3]).
l([2,3]).
busca:-
    mano3(X),
    %l(Y),
    movimientosPosibles(X, Y),
    write(Y).

**/
/**
 * Min max
 * ['pepe.pl'].
 * movimientosPosibles([[5,4],[8,1], [4,2], [4,0], [1,4]]).

https://es.wikipedia.org/wiki/Poda_alfa-beta
 * 
 **/
/*La funcion heuristica recibe los parámetros de la funEstimadora y la funPasa, 
los suma y regresa C. A es el número de fichas desconocidas, 
B, el número de fichas en el pozo, 
C es el número determinado del que quieres saber cuantas fichas quedan desconocidas. 
E es la lista cuando ha pasado el rival, 
ED el extremo derecho del tablero y EI, el izquierdo y S la suma de todo*/
heuristica(C, S):-
    numeros(Y), nth0(s,Y,D),
    extremoDerecho(ED), extremoIzquierdo(EI),
	length(desconocidas,A), pozo(B), notiene(E),
    funEstimadora(A, B, D, X), funPasa(E, ED, Y),funPasa(E, EI, Z),
	S is X+Y+Z.

funcionPeso(X):-
    random(1, 10, X).

/**
 * POSIBLES = [[5,4],[8,1], [4,2], [4,0], [1,4]]
 * LLAMADA INICIAL = alfabeta(origen, profundidad, -inf, +inf, max) 
 * */
% Caso en el que bajó hasta la profundidad deseada.
% alfabeta(Nodo, Profundidad, Alfa, Beta, Turno, Peso)
alfabeta(Nodo, 0, _, _, _, Peso):-
    funcionPeso(Nodo, Peso).
% MAX
alfabeta(Nodo, Prof, Alfa, Beta, 1, Peso):-
    posibles(X),
    % For para cada hijo del nodo
    Alfa is max(Alfa, alfabeta(Hijo, Prof-1, Alfa, Beta, 0)),
    Beta => Alfa,
    poda(Beta),
    Peso is Alfa.
% MIN
alfabeta(Nodo, Prof, Alfa, Beta, 0, Peso):-
    posibles(X),
    Beta is min(Beta, alfabeta(Hijo, Prof-1, Alfa, Beta, 1)),
    Beta =< Alfa,
    poda(Alfa),
    Peso is Beta.


max(X, Y, Z):-
    Z is max(X, Y).

min(X, Y, Z):-
    Z is min(X, Y).


/*la función estimadora recibe tres parámetros: ‘A’ que sería el num de fichas desconocidas, B el número de fichas en el pozo y C el número de fichas desconocidas de número determinado. Regresa D*/
funEstimadora(A, B, C, D):-
	(B=0) -> D is 0;
	(B\=0) -> D is 2*(1-(C/A)).


/*funMano([],_,_).
funMano([A|ColaA], F, S):-
    member(F, A), (S=0) -> S is S+1;
    funMano(ColaA, F, S).*/

/*La función recibe  la lista A que consiste en los casos qconocidos en los cuales el rival ha pasado, y el elemento B que es uno de los extremos del tablero, regresa C
*/

funPasa(A, B, C):-
    member(B, A) -> C is 2;
    C is 0.
