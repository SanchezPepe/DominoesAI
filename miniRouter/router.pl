:-ensure_loaded(metro).

/**
 * Calcular la norma euclidiana de dos estaciones, se proporcionan como parámetros 
 * las cordenadas X,Y de cada estación (latitud y longitud).
 **/
normaEuclidiana(X1, Y1, X2, Y2, Norm):-
    X is (X2-X1),
    Y is (Y2-Y1), 
    SUM is (X*X) + (Y*Y),
    N is 100*sqrt(SUM),
    round(N, 2, Norm).

norma(Station1,Station2,Dist):-
    station(_,Station1,Cord1,Cord2,_,_),
    station(_,Station2,C1,C2,_,_),
    normaEuclidiana(Cord1,Cord2,C1,C2,Dist),!.

/**
 * REGLAS AUXILIARES:
 * Obtiene la cabeza y la cola de la lista dada 
 * **/
getHead([H|_], Head):-
    Head = H.

getTail([_|T], Tail):-
    Tail = T.

/**
 * Obtiene el último elemento de una lista
 * **/
getLast(List, Last):-
    reverse(List, Rev),
    getHead(Rev, Last).

/**
 * Redondea un número, se indica la cantidad de digitos 
 * **/
round(Num, Digits, Ans):- 
    Z is Num * 10^Digits, 
    round(Z, ZA), 
    Ans is ZA / 10^Digits.

/**
 * Obtiene el valor peso g(n) de un nodo en particular
 * **/
getG(Node, Ans):-
    getHead(Node, Values),
    getHead(Values, Ans).

/**
 * Obtiene el valor heurístico h(n) de un nodo en particular
 * **/
getH(Node, Ans):-
    getHead(Node, Head),
    reverse(Head, R),
    getHead(R, Ans).

/**
 * Obtiene el nombre de la estación dado un nodo
 * **/
getName([_,_,Station, _], Name):-
    Name = Station.
getName([_,Station, _], Name):-
    Name = Station.

/**
 * Cuenta el número de estaciones que tiene una línea para un determinado sistema (mb o metro) 
 * **/
numStations(System, Line, Count):-
    aggregate_all(count, station(System,_,_,_,Line,_), Count).

/**
 * Regla que implementa una lista como una cola de prioridades, añade un nodo a la cola depiendo de su valor
 * f(n) = g(n) + h(n). Si la cola no existe, se crea con el elemento dado.
 * **/
addToPriorityQueue(Elem, _, [], First):-
    First = [Elem], !.
addToPriorityQueue(Node, Priority, [Queue|Tail], Ans):-
    getHead(Queue, Weights),
    getHead(Weights, G),   
    getLast(Weights, H),
    HeadPriority is G + H,    % Prioridad del primer elemento de la cola
    Priority > HeadPriority,
    addToPriorityQueue(Node, Priority, Tail, Rest),
    append([Queue], Rest, Ans), !.
addToPriorityQueue(Node, _, Queue, Ans):-
    append([Node], Queue, Ans), !.

/**
 * Regla que toma el primer elemento de la cola, lo retira y devuelve el elemento eliminado y el resto
 * de la cola de prioridades.
 * **/
popPriorityQueue([Queue|T], Rest, Elem):-
    Rest = T, 
    Elem = Queue.

/**
 * Regla que obtiene las estaciones adyacentes de la misma línea para una estación dada, se regresa una lista
 * con la estación que está a la izquierda y con la estación que está a la derecha del nodo a evaluar si se trata 
 * de una estación intermedia. Si se trata de una estación 'terminal' se devuelve sólo 1 estación.
 * **/
adyacentStations([System, Station, Line], Stations):-
    station(System, Station, _, _, Line, Index),
    L is Index-1,
    R is Index+1,
    numStations(System, Line, Count),
    (L > 0, R =< Count -> station(System,Left,_,_,Line, L), station(System,Right,_,_,Line, R), Stations = [Left, Right] 
    ; (L =:= 0 -> station(System,Right,_,_,Line, R), Stations = [Right] ; station(System,Left,_,_,Line, L), Stations = [Left])), !.

/**
 * Reglas que buscan en la base de conocimiento las estaciones con el mismo nombre y las guardan en una lista,
 * las estaciones obtenidas representan las estaciones de transbordo en los diferentes sistemas y líneas.
 * **/
getSameStations(Station, Conections):-
    findall([System, Station, Line] ,station(System,Station,_,_,Line,_),Conections).

getConnections([_, Sys, Node, Line], Connection):-
    getSameStations(Node, Con),
    delete(Con, [Sys,Node,Line], Connection).

/**
 * Reglas que permiten conocer la dirección a tomar en la línea. Las estaciones están ordenadas de Norte a Sur
 * y de Oeste a Este. Devuelve un número entero que indica si se tiene que 'subir' o 'bajar' en la línea.
 * **/
checkDirection([H|[T]],Start,Goal,Line, Direction):-
    norma(H,Goal, Left),
    norma(T,Goal, Right),
    station(_, Start, _ ,_, Line, Index),
    (Left < Right -> Direction is Index-1 ; Direction is Index+1).
checkDirection([H|[]],Start, _,Line, Dir):- % Si es terminal o inicio de línea
    station(_,Start,_,_,Line,StartOrder),    
    station(_,H,_,_,Line,Order),
    Dif is StartOrder-Order,
    (Dif > 0 -> Dir is StartOrder-1 ; Dir is StartOrder+1).

/**
 * Regla que permite conocer la dirección a tomar en la línea cuando se está en una estación terminal
 * **/
getDirection([Sys, Node, Line], Goal, New):-
    adyacentStations([Sys, Node, Line], Stations),
    checkDirection(Stations, Node, Goal, Line, Dir), 
    station(Sys, Next, _ , _, Line, Dir),
    New = [Sys, Next, Line], !.

/**
 * Regla que obtiene las estaciones adyacentes de las estaciones que cuentan con transbordos, esta regla
 * permite conectar las difentes líneas y sistemas entre sí para realizar la búsqueda.
 * **/
getAdyacentStationsCon([], _, Ans):-
    Ans = [].
getAdyacentStationsCon(Connections, Goal, Ans):-
    getHead(Connections, Head),
    getDirection(Head, Goal, Next),
    getTail(Connections, Rest),
    getAdyacentStationsCon(Rest, Goal, Con),
    append([Next], Con, Ans), !.

/**
 * Regla que obtiene los valores G y H de una estación determinada estos valores se obtienen en función de
 * la estación anterior a la estación a evaluar, se incrementa el valor G (peso actual) y se calcula el valor
 * heurístico H
 * **/
nodeValue([Sys|[Node|[Line]]], Goal, Prev, PrevG, List):-
    (norma(Node, Prev, G) -> SumG is G + PrevG ; SumG is PrevG),   % Peso del nodo previo al actual
    norma(Node, Goal, H),   % Valor heurístico
    List = [[SumG,H],Sys, Node, Line].

/**
 * Regla que recibe los nodos hijos de una estación determinada y se obtienen los valores G y H para cada uno
 * Realiza el cálculo del valor F para cada nodo de la lista y con el mismo, inserta el nodo en la
 * una cola de prioridades.
 * **/    
weightNodes([], _, _, _, _).
weightNodes(Nodes, Goal, PrevName, PrevG, Weighted):-
    getTail(Nodes, Tail),
    weightNodes(Tail, Goal, PrevName, PrevG, W),
    getHead(Nodes, Head),
    nodeValue(Head, Goal, PrevName, PrevG, NodeVal),
    getHead(NodeVal, Weights),
    getHead(Weights, G),   
    getLast(Weights, H),
    F is G + H,
    addToPriorityQueue(NodeVal, F, W, Weighted), !.

/**
 * Regla que obtiene la siguiente estación dada una en formato compatible con la cola de prioridades implementada.
 * **/   
getNextStation([_,_, Prev, _], [_, Sys, Node, Line], Next):-
    station(Sys,Node, _, _, Line, IndexNode),
    station(Sys,Prev, _, _, Line, IndexPrev),
    numStations(Sys, Line, Count),
    (IndexNode =:= 1 -> Direction is 2 ; (IndexNode =:= Count -> Direction is Count-1 ; Direction is IndexNode + (IndexNode - IndexPrev))),
    station(Sys,Name, _, _, Line, Direction),    
    Next = [Sys, Name, Line], !.


/**
 * Regla obtiene la estación anterior para iniciar la búsqueda A*, en este caso en que no se conoce la estación previa ya sea porque 
 * hubo un cambio de línea o sistema, o por que la estación de inicio es una terminal.
 * **/   
getPreviousFirst([Sys, Node, Line], Goal, Next):-
    adyacentStations([Sys, Node, Line], [H|[T]]),
    station(Sys,Node, _, _, Line, IndexNode),
    norma(H,Goal, Left),
    norma(T,Goal, Right),
    (Left < Right -> Direction is IndexNode +1 ; Direction is IndexNode -1),
    station(Sys,Name, _, _, Line, Direction),    
    Next = [[0,0],Sys, Name, Line].
getPreviousFirst([Sys, Node, Line], _, Next):-
    Next = [[0,0],Sys, Node, Line].    


/**
 * Regla que obtiene los nodos hijo de una estación determinada, los nodos hijos comprende la estación siguiente y las estaciones de transbordo
 * a otra línea o sistema
 * **/   
getChildNodes(Prev, Parent, Goal, WeightedChilds):-
    getNextStation(Prev, Parent, Next), % Estación siguiente en la misma línea
    getConnections(Parent, Conections),
    getAdyacentStationsCon(Conections, Goal, AdCon), % Estaciones de transbordo
    append(AdCon, [Next], Childs), 
    (Prev \= [] -> getTail(Prev, PTail) ; PTail is " "),
    delete(Childs, PTail, Cons),
    getName(Prev, PrevName),
    getG(Prev, PrevG),
    weightNodes(Cons, Goal, PrevName, PrevG , WeightedChilds), !.

/**
 * Regla que implementa la búsqueda A*, se proporciona el nodo anterior el inicio y el destino, 
 * devuelve una lista de estaciones a recorrer para llegar al destino.
 * **/
a_star(Prev, Parent, Goal, Path):-
    getName(Parent, PName),
    PName \= Goal,
    getChildNodes(Prev, Parent, Goal, Childs), % Obtiene los nodos hijos para la estación actual
    getHead(Childs, Succesor), % Obtiene el primer hijo ordenado (f(n) más chico)
    a_star(Parent, Succesor, Goal, Closed),
    append([PName], Closed, Path), !.
a_star(_, _, Goal, Path):-
    Path = [Goal]. % Si se llegó al destino, Start = Goal


/**
 * Método que inicializa la búsqueda A* para una estación en particular.
 * **/
getPath(Start, Goal, Path):-
    station(Sys, Start,_,_,Line,_),
    getPreviousFirst([Sys, Start, Line], Goal, First),
    a_star(First, [[0,0], Sys, Start, Line], Goal,Path).

/**
 * newCase(input)
 * Agrega un nuevo caso a la memoria de datos.
 * La memoria de datos se guarda en un .txt llamado caseFile.txt
 * Debe estar en la carpeta del proyecto.
 * Recibe un parámetro de entrada que es una lista
 * que contiene una ruta.
 **/
newCase(List) :-
    open('caseFile.txt', append, Stream),
    (write(Stream, List),
    write(Stream,"."),
    nl(Stream),
    !;
    true),
    close(Stream).

/**
 * returnAllCases(output)
 * Lee la memoria de casos y los regresa todos en una lista
 * Recibe un parámetro de salida que es una lista.
 **/
returnAllCases(List):-
  setup_call_cleanup(
    open('caseFile.txt', read, In),
    readInfo(In, List),
    close(In)).

/**
 * readInfo(input,output)
 * Lee un archivo y lo regresa como lista
 **/
readInfo(In, L):-
  read_term(In, H, []),
    (H == end_of_file ->  L = [];
      L = [H|T],
      readInfo(In,T)).

/**
 * compatibleCase(input,input,output)
 * Regresa una ruta en la cual estén contenidas las dos estaciones
 * i: Estación 1
 * i: Estación 2
 * o: Ruta
**/
compatibleCase(Station1,Station2,Case):-
    returnAllCases(CaseList),
    auxCompatibleCase(Station1,Station2,CaseList,Case).

/**
 * auxCompatibleCase(input,input,input,output)
 * Verifica si las estaciones están en un caso
 * input1: Estación 1
 * input2: Estación 2
 * input3: Ruta visitada
 * output: Ruta
**/
auxCompatibleCase(_,_,[],[]).
auxCompatibleCase(Station1, Station2,[Current|Tail],Case):-
    (member(Station1,Current),member(Station2,Current) ->
    Case = Current);
    auxCompatibleCase(Station1,Station2,Tail,Case), !.

/**
 * adaptCase(input,input,input,output)
 * Acota el la ruta recibida, a las dos estaciones de entrada
 * input1: Estación 1
 * input2: Estación 2
 * input3: Ruta
 * output: Ruta que empiece en una estación y termine en la otra
**/
adaptCase(Station1,Station2,Caso,Res):-
    findCase(Station1,Station2,Caso,Res1),
    reverse(Res1,Res2),
    findCase(Station1,Station2,Res2,Res3),
    reverse(Res3,Res).

/**
 * findCase(input,input,input,output).
 * Busca un caso que tenga de inicio o fin alguna de las dos estaciones
 * 
 * input1: Estación 1
 * input2: Estación 2
 * input3: Ruta
 * output: Ruta que empiece en una estación y termine en la otra
**/
findCase(_,_,[],[]):-
    !.
findCase(Station1,_,[Station1|Tail],[Station1|Tail]):-
    !.
findCase(_,Station2,[Station2|Tail],[Station2|Tail]):-
    !.
findCase(Station1,Station2,[_|Tail],Res):-
    findCase(Station1,Station2,Tail,Res).
    
/**
 * imprime(input,input)
 * Revisa si la ruta dada está en el correcto orden. * 
 * input1: Lista
 * input2: Origen de la ruta deseada
 **/
imprime([Head|Tail],Origen):-
    (Head == Origen -> printList([Head|Tail]);
    reverse([Head|Tail],NewList),printList(NewList)).

/**
 * printList(input)
 * Imprime el contenido de una lista.
**/
printList([]) :-
    write("¡Has llegado a tu destino!"),nl,!.
printList([Head|Tail]) :-
       write(Head),write(" -> "),
       printList(Tail).

/**
 * listNotEmpty(input)
 * Revisa si la lista está vacía
 * input: Lista
**/
listNotEmpty([]):-
    false.
listNotEmpty([_|_]):-
    true.

/**
 * getRoute(input,input,output)
 * Revisa si hay una ruta previamente calculada.
 * En caso afirmativo, la saca de la memoria de datos y la adapta.
 * En caso negativo, llama a aStar y la calcula. * 
 * input1: Estación origen
 * input2: Estación destino
 * output: Ruta
**/
getRoute(Origen,Destino,Ruta):-
    compatibleCase(Origen,Destino,Case),
    (listNotEmpty(Case) ->
    adaptCase(Origen,Destino,Case,Ruta),newCase(Ruta);
    getPath(Origen,Destino,Ruta),newCase(Ruta)).

:-dynamic closest/1.

normaAux(X1,X2,Est2,Dist):-
    station(_,Est2,Cord1,Cord2,_,_),
    normaEuclidiana(X1,X2,Cord1,Cord2,Dist),!.
/**
 * closestStation(Latitud,Longitud)
 * Se dan las coordenadas y regresa la estacion más cercana
**/
closestStation(Latitud,Longitud,Station):-
    findall(X,station(_,X,_,_,_,_),L),
    closestStation1(Latitud,Longitud,_,100000,L),
    retract(closest(Station)).

closestStation1(_,_,St,_,[]):-
   assert(closest(St)),
   !.

%Si la distancia calculada por la norma es
closestStation1(Latitud,Longitud,_,DistActual,[Start|Rest]):-    
    normaAux(Latitud,Longitud,Start,Dist),
    Dist=<DistActual,
    closestStation1(Latitud,Longitud,Start,Dist,Rest).

closestStation1(Latitud,Longitud,StationName,DistActual,[_|Rest]):-
    closestStation1(Latitud,Longitud,StationName,DistActual,Rest),!.


/**
 * main.
 * Es la ejecución del programa.
 * Pide (desde la consola) el origen y destino del viaje, y regresa una ruta.
 * Pregunta si el usuario desea obtener otra ruta.
*/
main:-
    write("Bienvenido a Weis, el mejor sistema inteligente de navegación en la CDMX."),nl,main2.
main2:-
    write("Por favor ingrese el origen de su viaje."),nl,
    read(Origen),
    write("Ahora, escriba el destino de su viaje."),nl,
    read(Destino),
    (station(_,Origen,_,_,_,_),station(_,Destino,_,_,_,_) -> 
    getRoute(Origen,Destino,Ruta);
    write("Ha habido un error ingresando el origen o el destino."),nl,main2),
    write("La ruta a seguir es: "),nl,
    imprime(Ruta,Origen),
    write("¿Desea hacer otro viaje?"),nl,read(Respuesta),
    (Respuesta == si -> main2;
    write("Gracias por usar Weis.")),!.
