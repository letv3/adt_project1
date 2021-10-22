# PDT2021 Zadanie 2
## Oleksandr Lytvyn

1. V tomto selecte DBMS engine spravil vyhladavani pomocou sekvencneho skenu. Spravil to preto 
ze udaj v tabulke nie su rozsortovane + nie je implementovana ziadna metoda na jednoznacne porovnanie
doch prvkov
![img.png](img.png)
2. 1 worker pracoval na tomto selecte (1145ms). Pri zvacseni poctu workerov na 2 pomocou 
`max_parallel_workers_per_gather` a tym padom sa zrychlilo vykonavanie dopytu o 292 ms (858ms). Pri nalsedovnom zvacseni
poctu workerov cas dopytu sa vyrazne nemeni do 3 a 4 execution time sa znizoval - 801ms a 796ms. Pri dalsom zvaceni poctu 
workerov execution time zacal stupa 5-829,6 - 834. Pricinou toho je pocet jadier na PC, co je 4. Tak ze optimalnym poctom
workerov je 4.
![img_1.png](img_1.png)
3. Cas oproti pozidaviek bez index sa vyrazne zmenil (796ms -> 0.092ms). Pri zvaceni poctu na 4 workerov execution time sa 
zmensil na 0.043ms (planning time: 0.114). V tejto poziadavne planovac nepotrebuje zvacsenie poctu workrev (rychlost sa 
zvacsuje nevyrazne). Vytvorenie indexu sortuje data, a preto pomocou Btree algotirhmu vieme rychlos dostat vysledok.
![img_2.png](img_2.png)
![img_3.png](img_3.png)
4. Spravanie je rovnake ako v 1 ulohe (resp. Seq Scan). Preto ze sme vytvorili index iba na jeden stlpec('screen_name').
Index na stlpec folowers_count nemame :(, zatial
![img_4.png](img_4.png)
5. Najprv planovac prejede kazdy potrebny zaznam (ktory vyhovuje podmienke) a potom spravi recheck, 
aby overit spravnost operacie. Potom sa zobrazil pocet blockov ktore ktore boli navsteveni (visited) a nie su lossy.
Potom sa Vykona BitmapIndexScan a ked sa vyskytne index ktory vyhovuje podmienke hladania, sa najde heap address na 
ktory ukazuje index ako offset v bitmap a tento bit zmenime na 1. Recheck condition je tam preto ze pri BitmapHeapScan
bitmap riadkov pri velkych tabulkach sa nezmesti do pamate, a preto uklada bitmap blockov, a tym padom stava lossy.
![img_5.png](img_5.png)
6. Rozdiel je v tom ze v tomto dopyte sa vykonal iba skvencny sken tabulky. Pri selektovani vacsieho poctu riadko z 
tabulky planovac sa rozhodne rovno precita celu tabulky, co bude rychlejsie nez proces z minulej otazky.
![img_6.png](img_6.png)
7. Vytorenie indexov trvalo 2min12s, insert trval 56ms. Opakovane vytvorenie indexov trvalo 2min17s. Skusil som to
to spravit este raz, vysledky boli rovnake, vytvorenie + insert: 2min12sec a vytvorenie po dropnuti: 2min13sec. Trva 
to o 1 sekundu dlhsie kvoli to ze bol pridany jeden zaznam? 
8. Dlzka vytvorenia indexu pre retweet_count - 35s228ms, Dlzka vytvorenia indexu pre contex_idx - 5min27s
Rozdiel v case vytvarania indexov je sposobeny tym ze tweet_count su hodnoty int, a content je string 
(porovnovanie string je narocnejsie operacia nez porovnanie int) Dlzka vytvorenie indexu zalezi od typu, velkosti a poctu 
hodnot nad ktorymi vytvarame index
9. Tabulky pre porovnanie indexov v poradi: retweet_count, content, name, friends_count, description
![img_7.png](img_7.png)

![img_8.png](img_8.png)

10. Prva query bola s indexom, druha - bez. Mozeme pozorovat ze pri query s indexom execution a planning time boli vacsie
nez pri query po zmazani indexu. Hoci v oboch pripadoch sa vykonava seq. scan, ale v pripade existencii indexu, planovac sa
snazi brat do uvahy index. Planovac ne pouzil Index Scan preto ze tento index pozaduje viacero IO operacii pre kazdy riadok
(vyhadat riadok v indexe, a vytiahnut riadok z heap), ted Seq scan vykona ib jedno citanie a uz bude vediet vysledok pre 
riadok.
![img_9.png](img_9.png)
11. Index sa nepouzil. Bol pouzity seq.scan. 
![img_10.png](img_10.png)
12. `CREATE INDEX content_idx_ops ON tweets (content text_pattern_ops);` pomocou tohto prikazu sme vytvorili 
btree index, ktory pouziva specialne urceny operation class.
![img_11.png](img_11.png) 
Ale pri selecte s _Gates_, planovac  znovu pouzil sekvencny skan, co sposobene velkym poctom vratenych riadkov (111886).
A pri takomto pocte vratenych riadkov pozitije seq.scan viac optimalnym riesenim. 
![img_12.png](img_12.png)
13. `CREATE INDEX content_idx_idiot ON tweets (content text_pattern_ops) WHERE content LIKE '%idiot #QAnon';` - vytvorime
index ktory najde tweet ktory konci na "idiot #QAnon". Pri selecte zobrazenom na brazku boli pouzite Bitmap Index 
Scan vyprodukuje bitmap lokacie potencialneho riadku, a posle bitmap do Bitmap HeapScan, ktory vyhlada samotny riadok pomocu
bitmap a vrati najviac vyhovujuce vysledky. Potom sa spravi Reacheck condition pre
dane riadok, aby overit spravnost vysledkov.
![img_13.png](img_13.png)
14. Najprv som vykonal query bez ziadnych indexov, ktora spravi iba sekvencny sken a rozsortuje hodnoty
`EXPLAIN SELECT * FROM accounts WHERE followers_count < 10 AND friends_count > 1000 ORDER BY statuses_count DESC`
potom som spravil index pre _followers_count_ : `CREATE INDEX followers_count_idx on accounts (followers_count);` 
ten isty select uz pouziva index, a rychlost sa zvacsila (1s198ms).

![img_14.png](img_14.png)

Potom som pridal index pre _friends_count_ : `CREATE INDEX friends_count_idx on accounts (friends_count);` 
Ten isty select z roznymi indexami mensimi indexami (1s178ms). Z explainu vidime ze Index friends_count_idx, obsahuje
bitmap na 1826k riadkov, a Potom sa uskutocni BitmapAND, co je redundantna operacia pri pocte takom pocte riadkov.
Teda overit kazdy zazname accountov najdenych v podla followers_count_idx ci ma friends_count > 1000, je viac optimalne
nez vyhladavat novy bitmap pre 1826k riadkov a potom este robit BitmapAnd. Tak ze vyrazne vykonnost sa neovlyvny, ale 
v tomto pripade este musime ukladovat aj index pre friends_count, co tiez zabera niejake miesto.
Robit index pre stlpec _statuses_count_ vobec nie je zmysel, preto ze pouziva sa iba na sortovanie.

![img_15.png](img_15.png)

15. Spravil som complex index pomocu nasledujucej query `CREATE INDEX friend_followers_idx on accounts (followers_count, friends_count);`
Query s predoslej ulohy prebiehla za 130ms, co je vyrazny narast rycholsti. Zvacsenie vykonyu sposobene tym ze uz mame bitmap pre
vsetky potrebne riadky, a teda iba musime vyhladat samotne riadky a overi ci naozaj vyhovuju poziadavke. Vytvorenim komplexneho indexu
sme eliminuvali potrebu BitmaAnd alebo filtrovanie, ako to bolo v predoslej ulohe


![img_16.png](img_16.png)

16. Query bola upravena nasledovne: `SELECT * FROM accounts WHERE followers_count < 1000 AND friends_count > 1000 ORDER BY statuses_count DESC`
A v tejto query planovac sa rozhodol vykonat seq. scan. Planovac spravil seq. scan preto ze vystup obsahoval vela riadkov (740655),
a v predoslom pripade to bolo  velmi malo riadkov (iba 719).
![img_17.png](img_17.png)

17. 