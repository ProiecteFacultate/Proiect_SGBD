SELECT * 
FROM Clienti;

SELECT * 
FROM Informatii_Clienti;

SELECT * 
FROM Informatii_Bancare;

SELECT * 
FROM Carduri_Bancare;

SELECT * 
FROM Adrese;

SELECT * 
FROM Facturi;

SELECT * 
FROM Plangeri;

SELECT * 
FROM Muncitori;

SELECT * 
FROM Informatii_Muncitori;

SELECT * 
FROM Specializari;

SELECT * 
FROM Interventii;

SELECT * 
FROM Documente;

SELECT * 
FROM Specializari_Muncitori;

UPDATE Facturi SET status = 'Platit' WHERE cod_client = 11;
COMMIT;


--6
CREATE OR REPLACE PROCEDURE cerinta_6 IS
   TYPE vector_orase IS VARRAY(20) OF Adrese.oras%TYPE;
   TYPE tabel_orase IS TABLE OF Adrese.oras%TYPE INDEX BY PLS_INTEGER;
   TYPE tabel_clienti IS TABLE OF clienti.email%TYPE INDEX BY PLS_INTEGER;
   v_vector_orase vector_orase := vector_orase('Chisinau', 'Craiova', 'Bucuresti', 'Iasi', 'Bacau', 'Kiev', 'Beijing');
   v_tabel_orase tabel_orase;
   v_tabel_clienti tabel_clienti;     --retine id-ul pt un client
   v_numar_adrese NUMBER(4);
   v_minim_o_adresa BOOLEAN;
   v_email Clienti.email%TYPE;
   j NUMBER(4);
BEGIN

      SELECT DISTINCT oras          --punem toate orasele in v_tabel_orase
      BULK COLLECT INTO v_tabel_orase
      FROM Adrese;
             
      FOR i IN v_vector_orase.FIRST..v_vector_orase.LAST LOOP      --scoatem din v_tabel_orase orasele care sunt in v_vector_orase
         j := v_tabel_orase.FIRST;
         WHILE(j IS NOT NULL) LOOP
            IF v_vector_orase(i) = v_tabel_orase(j) THEN
               v_tabel_orase.DELETE(j);
               EXIT;
            END IF;
            j := v_tabel_orase.NEXT(j);
         END LOOP;
      END LOOP;
      
      SELECT cod_client        
      BULK COLLECT INTO v_tabel_clienti
      FROM Clienti;
      
      FOR i IN v_tabel_clienti.FIRST..v_tabel_clienti.LAST LOOP
         v_minim_o_adresa := FALSE;
         j := v_tabel_orase.FIRST;
         
         SELECT email 
         INTO v_email
         FROM Clienti
         WHERE cod_client = v_tabel_clienti(i);
         
         WHILE(j IS NOT NULL) LOOP
            v_numar_adrese := 0;
            
             SELECT NVL2((SELECT COUNT(*)
                          FROM Adrese
                          WHERE cod_client = v_tabel_clienti(i)
                          AND oras = v_tabel_orase(j)
                          GROUP BY oras), (SELECT COUNT(*)
                                           FROM Adrese
                                           WHERE cod_client = v_tabel_clienti(i)
                                           AND oras = v_tabel_orase(j)
                                           GROUP BY oras), 0)
            INTO v_numar_adrese
            FROM dual;
            
            IF v_numar_adrese > 0 THEN
               DBMS_OUTPUT.PUT_LINE('Clientul cu mailul ' || v_email || ' are adresa in orasul ' || v_tabel_orase(j));
               v_minim_o_adresa := TRUE;
            END IF;
            
            j := v_tabel_orase.NEXT(j);
         END LOOP;
         
         IF v_minim_o_adresa = FALSE THEN
            DBMS_OUTPUT.PUT_LINE('Clientul cu mailul ' || v_email || ' nu are nicio adresa in orasele date');
         END IF;
      END LOOP;    
END;

            
DECLARE
BEGIN
   cerinta_6;
END;
        
        
        
-----------------------------------------------------------------7---------------------------------------------------------------
         
         
CREATE OR REPLACE PROCEDURE cerinta_7(v_numar_minim_plangeri IN NUMBER) IS
   CURSOR c_clienti (numar_minim NUMBER) IS   --retine clientii care au depus cel putin numar_minim plangeri in urma carora au rezultat interventii
      SELECT DISTINCT p.cod_client, c.nume_utilizator
      FROM Documente d, Plangeri p, Clienti c
      WHERE d.cod_client = p.cod_client
      AND d.cod_plangere = p.cod_plangere
      AND d.cod_client = c.cod_client
      GROUP BY p.cod_client, c.nume_utilizator
      HAVING COUNT(p.cod_plangere) > numar_minim;
      
   CURSOR c_muncitori IS                      --retine numele si prenumele si codul tuturor muncitorilor
      SELECT m.cod_muncitor cod, ic.nume nume, ic.prenume prenume
      FROM Muncitori m, Informatii_Muncitori ic
      WHERE m.cod_informatii_muncitor = ic.cod_informatii_muncitor;   
      
v_cod_client Clienti.cod_client%TYPE;
v_nume_utilizator Clienti.nume_utilizator%TYPE;
v_muncitor_lucreaza NUMBER(4);
v_cunosc_informatii BOOLEAN;
v_exista_clienti BOOLEAN := FALSE;
BEGIN
   OPEN c_clienti(v_numar_minim_plangeri);
   LOOP
      FETCH c_clienti INTO v_cod_client, v_nume_utilizator;
      EXIT WHEN c_clienti%NOTFOUND;
      v_exista_clienti := TRUE;
      v_cunosc_informatii := FALSE;
      
      FOR muncitor IN c_muncitori LOOP
         v_cunosc_informatii := TRUE;
         SELECT NVL2((SELECT COUNT(*)
                      FROM Documente 
                      WHERE cod_muncitor = muncitor.cod
                      AND cod_client = v_cod_client), (SELECT COUNT(*)
                                                       FROM Documente 
                                                       WHERE cod_muncitor = muncitor.cod
                                                       AND cod_client = v_cod_client), 0)
         INTO v_muncitor_lucreaza
         FROM dual;
         
         IF v_muncitor_lucreaza > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Pentru clientul ' || v_nume_utilizator || ' lucreaza muncitorul ' || muncitor.nume || ' ' ||  muncitor.prenume);
         END IF;
      END LOOP;
      
      IF v_cunosc_informatii = FALSE THEN
         DBMS_OUTPUT.PUT_LINE('Nu se cunoaste numele si prenumele niciunuia dintre muncitorii care au desemnati sa rezolve plangerile clientului ' || v_nume_utilizator);
      END IF;
   END LOOP;
   
   CLOSE c_clienti;
   
   IF v_exista_clienti = FALSE THEN
      DBMS_OUTPUT.PUT_LINE('Nu exista niciun client care sa depuna minim ' || v_numar_minim_plangeri || ' plangeri in urma carora sa exista interventii');
   END IF;
END;


DECLARE
BEGIN
   cerinta_7(1);
END;







--------------------------------------------------------------------8----------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cerinta_8(v_reducere IN NUMBER) RETURN NUMBER IS
   CURSOR c_facturi IS
   SELECT f.cod_factura cod_factura, f.cod_adresa cod_adresa, f.cod_client cod_client, f.total total, f.data_eliberare data_eliberare, f.termen_plata termen_plata, f.status status, a.tara tara, a.oras oras, a.strada strada, a.numar numar, c.nume_utilizator nume_utilizator
   FROM Facturi f, Adrese a, Clienti c
   WHERE f.cod_client = a.cod_client
   AND f.cod_adresa = a.cod_adresa
   AND a.cod_client = c.cod_client;

v_reducere_totala NUMBER := 0;
v_today DATE;
TERMEN_PLATA_DEPASIT EXCEPTION;
TOTAL_SUB_REDUCERE EXCEPTION;
FACTURA_DEJA_PLATITA EXCEPTION;
BEGIN

   SELECT SYSDATE 
   INTO v_today
   FROM dual;
   
   FOR factura IN c_facturi LOOP
       DBMS_OUTPUT.PUT_LINE('Pentru clientul ' || factura.nume_utilizator || ' la adresa ' || factura.tara || ', ' || factura.oras || ', ' || factura.strada || ', ' || factura.numar || ' factura eliberata pe data de ' || factura.data_eliberare || ': ');
      BEGIN
         
         IF factura.status = 'Platit' THEN RAISE FACTURA_DEJA_PLATITA;
         ELSIF factura.termen_plata < v_today AND factura.status = 'Neplatit' THEN RAISE TERMEN_PLATA_DEPASIT;
         ELSIF factura.total < v_reducere THEN RAISE TOTAL_SUB_REDUCERE;
         ELSE  
            v_reducere_totala := v_reducere_totala + v_reducere;     
            DBMS_OUTPUT.PUT_LINE('Reducerea de ' || v_reducere || ' a fost aplicata!');
            
            UPDATE Facturi 
            SET total = total - v_reducere
            WHERE cod_factura = factura.cod_factura
            AND cod_adresa = factura.cod_adresa
            AND cod_client = factura.cod_client;
         END IF;
         
         EXCEPTION 
            
            WHEN TERMEN_PLATA_DEPASIT THEN
               DBMS_OUTPUT.PUT_LINE('Termenul de plata a fost depasit! Totalul nu a fost redus, inse termenul de plata a fost extins pentru 1 Ianuarie 2024');
               
               UPDATE Facturi 
               SET termen_plata = TO_DATE('01-JAN-2024', 'DD-MON-YYYY')
               WHERE cod_factura = factura.cod_factura
               AND cod_adresa = factura.cod_adresa
               AND cod_client = factura.cod_client;

            WHEN TOTAL_SUB_REDUCERE THEN
               v_reducere_totala := v_reducere_totala + factura.total;
               DBMS_OUTPUT.PUT_LINE('Totalul de plata este mai mic decat reducerea, asa ca factura a fost actualizata ca fiind platita');
               
               UPDATE Facturi 
               SET status = 'Platit'
               WHERE cod_factura = factura.cod_factura
               AND cod_adresa = factura.cod_adresa
               AND cod_client = factura.cod_client;
               
            WHEN FACTURA_DEJA_PLATITA THEN
               DBMS_OUTPUT.PUT_LINE('Factura a fost deja platita');
      END;
      DBMS_OUTPUT.PUT_LINE(' ');
   END LOOP;
   
   RETURN v_reducere_totala;
END;


DECLARE                              --aici sunt evidentiate toate cazurile
v_reducere_totala NUMBER;
BEGIN
   v_reducere_totala := cerinta_8(500);
   DBMS_OUTPUT.PUT_LINE(' ');
   DBMS_OUTPUT.PUT_LINE('Reducere totala: ' || v_reducere_totala);
END;


SELECT * FROM CLIENTI;

SELECT * FROM ADRESE;

SELECT * FROM Facturi;

ROLLBACK;


--------------------------------------------------------9-------------------------------------------------------------

SELECT * FROM Clienti;
SELECT * FROM Adrese;
SELECT * FROM Facturi;
SELECT * FROM Informatii_Clienti;
SELECT * FROM Carduri_Bancare;
SELECT * FROM Informatii_Bancare;

UPDATE Informatii_Clienti Set nume = 'Ion', prenume = 'Vasile' where cod_informatii_client = 11;
INSERT INTO Informatii_clienti VALUES(12, 'NumeTest', 'PrenumeTest', '1111111111111', '0711111111');
INSERT INTO Clienti Values(13, 12, 'TestUsername' , 'testpass', 'test@yahoo');
INSERT INTO Informatii_Bancare VALUES (12, 13, 3000, 1000);
INSERT INTO Carduri_Bancare Values (12, 12, 13, '1111111111111111', TO_DATE('12-DEC-2050', 'DD-MON-YYYY'), 111);
INSERT INTO Carduri_Bancare Values (13, 12, 13, '2222222222222222', TO_DATE('12-DEC-2070', 'DD-MON-YYYY'), 222);
INSERT INTO Carduri_Bancare Values (14, 12, 13, '3333333333333333', TO_DATE('12-DEC-2090', 'DD-MON-YYYY'), 222);
INSERT INTO Adrese VALUES (1, 13, 'Romania', 'Craiova', 'Stadionului', 80);
INSERT INTO Facturi VALUES (1, 1, 13, 2000, TO_DATE('12-DEC-2020', 'DD-MON-YYYY'), TO_DATE('15-FEB-2025', 'DD-MON-YYYY'), 'Neplatit');

INSERT INTO Informatii_clienti VALUES(13, 'NumeTest2', 'PrenumeTest2', '1111111111112', '0711111112');
INSERT INTO Clienti Values(14, 13, 'TestUsername2' , 'testpass2', 'test2@yahoo');
INSERT INTO Informatii_Bancare VALUES (13, 14, 2500, 500);
INSERT INTO Carduri_Bancare Values (15, 13, 14, '1111111111111122', TO_DATE('12-DEC-2050', 'DD-MON-YYYY'), 111);
INSERT INTO Carduri_Bancare Values (16, 13, 14, '2222222222222233', TO_DATE('12-DEC-2070', 'DD-MON-YYYY'), 222);
INSERT INTO Adrese VALUES (1, 14, 'Romania', 'Craiova', 'Stadionului', 80);
INSERT INTO Facturi VALUES (1, 1, 14, 2000, TO_DATE('12-DEC-2020', 'DD-MON-YYYY'), TO_DATE('15-FEB-2025', 'DD-MON-YYYY'), 'Neplatit');
INSERT INTO Facturi VALUES (2, 1, 14, 3000, TO_DATE('01-APR-2019', 'DD-MON-YYYY'), TO_DATE('23-DEC-2024', 'DD-MON-YYYY'), 'Neplatit');
INSERT INTO Facturi VALUES (3, 1, 14, 1700, TO_DATE('12-DEC-2020', 'DD-MON-YYYY'), TO_DATE('15-FEB-2025', 'DD-MON-YYYY'), 'Neplatit');
INSERT INTO Facturi VALUES (4, 1, 14, 2700, TO_DATE('01-APR-2019', 'DD-MON-YYYY'), TO_DATE('23-DEC-2024', 'DD-MON-YYYY'), 'Neplatit');

INSERT INTO Informatii_clienti VALUES(14, 'NumeTest3', 'PrenumeTest3', '1111111111113', '0711111113');
INSERT INTO Clienti Values(15, 14, 'TestUsername3' , 'testpass3', 'test3@yahoo');
INSERT INTO Adrese VALUES (1, 15, 'Romania', 'Craiova', 'Stadionului', 80);
INSERT INTO Facturi VALUES (1, 1, 15, 3000, TO_DATE('12-DEC-2020', 'DD-MON-YYYY'), TO_DATE('15-FEB-2025', 'DD-MON-YYYY'), 'Neplatit');



CREATE OR REPLACE PROCEDURE cerinta_9(v_nume Informatii_Clienti.nume%TYPE, v_prenume Informatii_Clienti.prenume%TYPE) IS
CURSOR c_carduri (cod_client_param Clienti.cod_client%TYPE) IS  
      SELECT DISTINCT cb.numar_card, cb.cod_securitate_card
      FROM Carduri_Bancare cb, Informatii_Bancare ib, Clienti c, Informatii_Clienti ic, Adrese a, Facturi f
      WHERE cb.cod_client = cod_client_param
      AND ib.cod_client = cod_client_param
      AND ib.sold_curent > 2000
      AND a.cod_client = cod_client_param
      AND a.tara = 'Romania'
      AND f.cod_client = cod_client_param
      AND f.cod_adresa = a.cod_adresa
      AND f.status = 'Neplatit';

v_cod_client Clienti.cod_client%TYPE;
v_numar_card Carduri_bancare.numar_card%TYPE;
v_cod_securitate_card Carduri_bancare.cod_securitate_card%TYPE;
v_index_card NUMBER(4) := 1;
BEGIN

   SELECT c.cod_client      --aflare cod client
   INTO v_cod_client
   FROM Informatii_Clienti ic, Clienti c
   WHERE c.cod_informatii_client = ic.cod_informatii_client
   AND ic.nume = v_nume
   AND ic.prenume = v_prenume;
   
   OPEN c_carduri(v_cod_client);
   LOOP 
      FETCH c_carduri INTO v_numar_card, v_cod_securitate_card;
      EXIT WHEN c_carduri%NOTFOUND;
      DBMS_OUTPUT.PUT_LINE('Cardul ' || v_index_card || ': numar - ' || v_numar_card || ', cod securitate - ' || v_cod_securitate_card);
      v_index_card := v_index_card + 1;
   END LOOP;
   
   UPDATE Facturi
   SET status = 'Platit'
   WHERE cod_client = v_cod_client;
   
   EXCEPTION 
      WHEN NO_DATA_FOUND THEN DBMS_OUTPUT.PUT_LINE ('NO DATA FOUND!');
      WHEN TOO_MANY_ROWS THEN DBMS_OUTPUT.PUT_LINE ('PREA MULTE REZULTATE!');
      WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE ('ALTA EROARE!');
END;




DECLARE   -- no data found; din cauza ca nu exista niciun client cu numele si prenumele asta
BEGIN
   cerinta_9('AAAA', 'VVVV');
END;

DECLARE   -- to many rows; din cauza ca exista 2 clienti cu numele si prenumele astea
BEGIN
   cerinta_9('Ion', 'Vasile');
END;


DECLARE   -- no data found; din cauza ca desi exista o inregistrare in Informatii_Clienti cu numele si prenumele date, acea inregistrare nu este legata de niciun client din tabelul Clienti
BEGIN
   cerinta_9('Gigel', 'Frone');
END;

DECLARE   -- se afieaza cum trebuie
BEGIN
   cerinta_9('NumeTest', 'PrenumeTest');
END;

DECLARE   -- se afieaza cum trebuie desi sunt 2 facturi neplatite pe adrese de romania; se selecteaza ambele dar pentru ca folosim select distinct cardurile sunt luat o singura data
BEGIN
   cerinta_9('NumeTest2', 'PrenumeTest2');
END;

DECLARE   -- nu se afiseaza niciun card pt ca nu exista, dar se executa ok fara sa dea no data found
BEGIN
   cerinta_9('NumeTest3', 'PrenumeTest3');
END;

COMMIT;



---------------------------------------------------------------------------10-----------------------------------------------------------------


SELECT * FROM Muncitori;
SELECT * FROM informatii_muncitori;
   

CREATE OR REPLACE TRIGGER cerinta_10
   BEFORE INSERT OR UPDATE OR DELETE ON Muncitori
BEGIN
   IF (TO_CHAR(SYSDATE, 'D') = 1) THEN
      RAISE_APPLICATION_ERROR(-20001,'Tabelul nu se poate actualiza Duminica!');  
   ELSIF (TO_CHAR(SYSDATE, 'D') = 7) THEN
      RAISE_APPLICATION_ERROR(-20001,'Tabelul nu se poate actualiza Sambata!');
   ELSIF ((TO_CHAR(SYSDATE, 'D') = 6) AND (TO_CHAR(SYSDATE,'HH24') NOT BETWEEN 8 AND 16)) THEN
      RAISE_APPLICATION_ERROR(-20001,'Tabelul nu se poate actualiza vinerea inafara orelor 8:00-16:00');
   ELSIF (TO_CHAR(SYSDATE,'HH24') NOT BETWEEN 8 AND 20) THEN
      RAISE_APPLICATION_ERROR(-20001,'Tabelul nu se poate actualiza in timpul saptamanii inafara orelor 8:00-20:00');
   END IF;
END;

INSERT INTO Muncitori VALUES(14, NULL, 5000, TO_DATE('13-DEC-2017', 'DD-MON-YYYY'), 1000);



---------------------------------------------------------------------------11-----------------------------------------------------------------

SELECT * FROM Informatii_Bancare;
SELECT * FROM Facturi;

CREATE OR REPLACE TRIGGER cerinta_11
   BEFORE UPDATE OF status ON Facturi
   FOR EACH ROW
DECLARE
v_sold_curent Informatii_Bancare.sold_curent%TYPE;
BEGIN

   IF :NEW.status = 'Platit' THEN
      SELECT sold_curent
      INTO v_sold_curent
      FROM Informatii_Bancare
      WHERE cod_client = :NEW.cod_client;
   
      IF v_sold_curent < :NEW.total THEN
         RAISE_APPLICATION_ERROR(-20001, 'Clientul nu dispune de suficienti bani pentru a plati factura!');
      END IF;
    END IF;
    
    EXCEPTION   --pentru cazul in care clientul nu are inserare in informatii_bancare
       WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20001, 'Clientul nu are informatiile bancare setate!');
END;

UPDATE Facturi SET status = 'Platit' WHERE cod_client = 15; --ne trimite in exceptie pentru ca nu exista in tableul Informatii_Bancare un client cu codul 15
UPDATE Facturi SET status = 'Platit' WHERE cod_client = 10;    --exista inserare in Informatii_Clienti pentru clientul 10, dar nu dispune de suficienti bani

ROLLBACK;
COMMIT;
   
   

---------------------------------------------------------------------------12-----------------------------------------------------------------

CREATE OR REPLACE TRIGGER cerinta_12
   BEFORE CREATE OR DROP OR ALTER ON SCHEMA
DECLARE
v_operation VARCHAR(30) := SYS.SYSEVENT;
v_table_name VARCHAR2(30) := SYS.DICTIONARY_OBJ_NAME;
v_user VARCHAR(50) := SYS.LOGIN_USER;
BEGIN
   IF v_user != 'SYSTEM' THEN
      IF v_operation = 'CREATE' THEN
         RAISE_APPLICATION_ERROR(-20001, 'Nu aveti dreptul sa creati tabele noi! Tabelul ' || v_table_name || ' nu a fost creat.');
      ELSIF v_operation = 'ALTER' THEN
         RAISE_APPLICATION_ERROR(-20001, 'Nu aveti dreptul sa modificati tabele! Tabelul ' || v_table_name || ' nu a fost modificat.');
      ELSIF v_operation = 'DROP' THEN
         RAISE_APPLICATION_ERROR(-20001, 'Nu aveti dreptul sa stergeti tabele! Tabelul ' || v_table_name || ' nu a fost sters.');
      END IF;
   END IF;
END;


CREATE TABLE test (utilizator VARCHAR2(30), nume_bd VARCHAR2(50), eveniment VARCHAR2(20), nume_obiect VARCHAR2(30), data DATE);
ALTER TABLE Muncitori ADD TestColumn VARCHAR2(50);
DROP TABLE Clienti;















































------------------------------------------------------------------------13-------------------------------------------------------------------

CREATE OR REPLACE PACKAGE pachet_cerinta_13 AS
   PROCEDURE cerinta_6;
   PROCEDURE cerinta_7(v_numar_minim_plangeri IN NUMBER); 
   FUNCTION cerinta_8(v_reducere IN NUMBER) RETURN NUMBER; 
   PROCEDURE cerinta_9(v_nume Informatii_Clienti.nume%TYPE, v_prenume Informatii_Clienti.prenume%TYPE);
--   TRIGGER cerinta_10;
--   TRIGGER cerinta_11;
--   TRIGGER cerinta_12;
END pachet_cerinta_13;





CREATE OR REPLACE PACKAGE BODY pachet_cerinta_13 AS

PROCEDURE cerinta_6 IS
   TYPE vector_orase IS VARRAY(20) OF Adrese.oras%TYPE;
   TYPE tabel_orase IS TABLE OF Adrese.oras%TYPE INDEX BY PLS_INTEGER;
   TYPE tabel_clienti IS TABLE OF clienti.email%TYPE INDEX BY PLS_INTEGER;
   v_vector_orase vector_orase := vector_orase('Chisinau', 'Craiova', 'Bucuresti', 'Iasi', 'Bacau', 'Kiev', 'Beijing');
   v_tabel_orase tabel_orase;
   v_tabel_clienti tabel_clienti;     --retine id-ul pt un client
   v_numar_adrese NUMBER(4);
   v_minim_o_adresa BOOLEAN;
   v_email Clienti.email%TYPE;
   j NUMBER(4);
BEGIN

      SELECT DISTINCT oras          --punem toate orasele in v_tabel_orase
      BULK COLLECT INTO v_tabel_orase
      FROM Adrese;
             
      FOR i IN v_vector_orase.FIRST..v_vector_orase.LAST LOOP      --scoatem din v_tabel_orase orasele care sunt in v_vector_orase
         j := v_tabel_orase.FIRST;
         WHILE(j IS NOT NULL) LOOP
            IF v_vector_orase(i) = v_tabel_orase(j) THEN
               v_tabel_orase.DELETE(j);
               EXIT;
            END IF;
            j := v_tabel_orase.NEXT(j);
         END LOOP;
      END LOOP;
      
      SELECT cod_client        
      BULK COLLECT INTO v_tabel_clienti
      FROM Clienti;
      
      FOR i IN v_tabel_clienti.FIRST..v_tabel_clienti.LAST LOOP
         v_minim_o_adresa := FALSE;
         j := v_tabel_orase.FIRST;
         
         SELECT email 
         INTO v_email
         FROM Clienti
         WHERE cod_client = v_tabel_clienti(i);
         
         WHILE(j IS NOT NULL) LOOP
            v_numar_adrese := 0;
            
             SELECT NVL2((SELECT COUNT(*)
                          FROM Adrese
                          WHERE cod_client = v_tabel_clienti(i)
                          AND oras = v_tabel_orase(j)
                          GROUP BY oras), (SELECT COUNT(*)
                                           FROM Adrese
                                           WHERE cod_client = v_tabel_clienti(i)
                                           AND oras = v_tabel_orase(j)
                                           GROUP BY oras), 0)
            INTO v_numar_adrese
            FROM dual;
            
            IF v_numar_adrese > 0 THEN
               DBMS_OUTPUT.PUT_LINE('Clientul cu mailul ' || v_email || ' are adresa in orasul ' || v_tabel_orase(j));
               v_minim_o_adresa := TRUE;
            END IF;
            
            j := v_tabel_orase.NEXT(j);
         END LOOP;
         
         IF v_minim_o_adresa = FALSE THEN
            DBMS_OUTPUT.PUT_LINE('Clientul cu mailul ' || v_email || ' nu are nicio adresa in orasele date');
         END IF;
      END LOOP;    
END;



PROCEDURE cerinta_7(v_numar_minim_plangeri IN NUMBER) IS
   CURSOR c_clienti (numar_minim NUMBER) IS   --retine clientii care au depus cel putin numar_minim plangeri in urma carora au rezultat interventii
      SELECT DISTINCT p.cod_client, c.nume_utilizator
      FROM Documente d, Plangeri p, Clienti c
      WHERE d.cod_client = p.cod_client
      AND d.cod_plangere = p.cod_plangere
      AND d.cod_client = c.cod_client
      GROUP BY p.cod_client, c.nume_utilizator
      HAVING COUNT(p.cod_plangere) > numar_minim;
      
   CURSOR c_muncitori IS                      --retine numele si prenumele si codul tuturor muncitorilor
      SELECT m.cod_muncitor cod, ic.nume nume, ic.prenume prenume
      FROM Muncitori m, Informatii_Muncitori ic
      WHERE m.cod_informatii_muncitor = ic.cod_informatii_muncitor;   
      
v_cod_client Clienti.cod_client%TYPE;
v_nume_utilizator Clienti.nume_utilizator%TYPE;
v_muncitor_lucreaza NUMBER(4);
v_cunosc_informatii BOOLEAN;
v_exista_clienti BOOLEAN := FALSE;
BEGIN
   OPEN c_clienti(v_numar_minim_plangeri);
   LOOP
      FETCH c_clienti INTO v_cod_client, v_nume_utilizator;
      EXIT WHEN c_clienti%NOTFOUND;
      v_exista_clienti := TRUE;
      v_cunosc_informatii := FALSE;
      
      FOR muncitor IN c_muncitori LOOP
         v_cunosc_informatii := TRUE;
         SELECT NVL2((SELECT COUNT(*)
                      FROM Documente 
                      WHERE cod_muncitor = muncitor.cod
                      AND cod_client = v_cod_client), (SELECT COUNT(*)
                                                       FROM Documente 
                                                       WHERE cod_muncitor = muncitor.cod
                                                       AND cod_client = v_cod_client), 0)
         INTO v_muncitor_lucreaza
         FROM dual;
         
         IF v_muncitor_lucreaza > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Pentru clientul ' || v_nume_utilizator || ' lucreaza muncitorul ' || muncitor.nume || ' ' ||  muncitor.prenume);
         END IF;
      END LOOP;
      
      IF v_cunosc_informatii = FALSE THEN
         DBMS_OUTPUT.PUT_LINE('Nu se cunoaste numele si prenumele niciunuia dintre muncitorii care au desemnati sa rezolve plangerile clientului ' || v_nume_utilizator);
      END IF;
   END LOOP;
   
   CLOSE c_clienti;
   
   IF v_exista_clienti = FALSE THEN
      DBMS_OUTPUT.PUT_LINE('Nu exista niciun client care sa depuna minim ' || v_numar_minim_plangeri || ' plangeri in urma carora sa exista interventii');
   END IF;
END;



FUNCTION cerinta_8(v_reducere IN NUMBER) RETURN NUMBER IS
   CURSOR c_facturi IS
   SELECT f.cod_factura cod_factura, f.cod_adresa cod_adresa, f.cod_client cod_client, f.total total, f.data_eliberare data_eliberare, f.termen_plata termen_plata, f.status status, a.tara tara, a.oras oras, a.strada strada, a.numar numar, c.nume_utilizator nume_utilizator
   FROM Facturi f, Adrese a, Clienti c
   WHERE f.cod_client = a.cod_client
   AND f.cod_adresa = a.cod_adresa
   AND a.cod_client = c.cod_client;

v_reducere_totala NUMBER := 0;
v_today DATE;
TERMEN_PLATA_DEPASIT EXCEPTION;
TOTAL_SUB_REDUCERE EXCEPTION;
FACTURA_DEJA_PLATITA EXCEPTION;
BEGIN

   SELECT SYSDATE 
   INTO v_today
   FROM dual;
   
   FOR factura IN c_facturi LOOP
       DBMS_OUTPUT.PUT_LINE('Pentru clientul ' || factura.nume_utilizator || ' la adresa ' || factura.tara || ', ' || factura.oras || ', ' || factura.strada || ', ' || factura.numar || ' factura eliberata pe data de ' || factura.data_eliberare || ': ');
      BEGIN
         
         IF factura.status = 'Platit' THEN RAISE FACTURA_DEJA_PLATITA;
         ELSIF factura.termen_plata < v_today AND factura.status = 'Neplatit' THEN RAISE TERMEN_PLATA_DEPASIT;
         ELSIF factura.total < v_reducere THEN RAISE TOTAL_SUB_REDUCERE;
         ELSE  
            v_reducere_totala := v_reducere_totala + v_reducere;     
            DBMS_OUTPUT.PUT_LINE('Reducerea de ' || v_reducere || ' a fost aplicata!');
            
            UPDATE Facturi 
            SET total = total - v_reducere
            WHERE cod_factura = factura.cod_factura
            AND cod_adresa = factura.cod_adresa
            AND cod_client = factura.cod_client;
         END IF;
         
         EXCEPTION 
            
            WHEN TERMEN_PLATA_DEPASIT THEN
               DBMS_OUTPUT.PUT_LINE('Termenul de plata a fost depasit! Totalul nu a fost redus, inse termenul de plata a fost extins pentru 1 Ianuarie 2024');
               
               UPDATE Facturi 
               SET termen_plata = TO_DATE('01-JAN-2024', 'DD-MON-YYYY')
               WHERE cod_factura = factura.cod_factura
               AND cod_adresa = factura.cod_adresa
               AND cod_client = factura.cod_client;

            WHEN TOTAL_SUB_REDUCERE THEN
               v_reducere_totala := v_reducere_totala + factura.total;
               DBMS_OUTPUT.PUT_LINE('Totalul de plata este mai mic decat reducerea, asa ca factura a fost actualizata ca fiind platita');
               
               UPDATE Facturi 
               SET status = 'Platit'
               WHERE cod_factura = factura.cod_factura
               AND cod_adresa = factura.cod_adresa
               AND cod_client = factura.cod_client;
               
            WHEN FACTURA_DEJA_PLATITA THEN
               DBMS_OUTPUT.PUT_LINE('Factura a fost deja platita');
      END;
      DBMS_OUTPUT.PUT_LINE(' ');
   END LOOP;
   
   RETURN v_reducere_totala;
END;



PROCEDURE cerinta_9(v_nume Informatii_Clienti.nume%TYPE, v_prenume Informatii_Clienti.prenume%TYPE) IS
CURSOR c_carduri (cod_client_param Clienti.cod_client%TYPE) IS  
      SELECT DISTINCT cb.numar_card, cb.cod_securitate_card
      FROM Carduri_Bancare cb, Informatii_Bancare ib, Clienti c, Informatii_Clienti ic, Adrese a, Facturi f
      WHERE cb.cod_client = cod_client_param
      AND ib.cod_client = cod_client_param
      AND ib.sold_curent > 2000
      AND a.cod_client = cod_client_param
      AND a.tara = 'Romania'
      AND f.cod_client = cod_client_param
      AND f.cod_adresa = a.cod_adresa
      AND f.status = 'Neplatit';

v_cod_client Clienti.cod_client%TYPE;
v_numar_card Carduri_bancare.numar_card%TYPE;
v_cod_securitate_card Carduri_bancare.cod_securitate_card%TYPE;
v_index_card NUMBER(4) := 1;
BEGIN

   SELECT c.cod_client      --aflare cod client
   INTO v_cod_client
   FROM Informatii_Clienti ic, Clienti c
   WHERE c.cod_informatii_client = ic.cod_informatii_client
   AND ic.nume = v_nume
   AND ic.prenume = v_prenume;
   
   OPEN c_carduri(v_cod_client);
   LOOP 
      FETCH c_carduri INTO v_numar_card, v_cod_securitate_card;
      EXIT WHEN c_carduri%NOTFOUND;
      DBMS_OUTPUT.PUT_LINE('Cardul ' || v_index_card || ': numar - ' || v_numar_card || ', cod securitate - ' || v_cod_securitate_card);
      v_index_card := v_index_card + 1;
   END LOOP;
   
   UPDATE Facturi
   SET status = 'Platit'
   WHERE cod_client = v_cod_client;
   
   EXCEPTION 
      WHEN NO_DATA_FOUND THEN DBMS_OUTPUT.PUT_LINE ('NO DATA FOUND!');
      WHEN TOO_MANY_ROWS THEN DBMS_OUTPUT.PUT_LINE ('PREA MULTE REZULTATE!');
      WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE ('ALTA EROARE!');
END;



--TRIGGER cerinta_10 
--   BEFORE INSERT OR UPDATE OR DELETE ON Muncitori
--BEGIN
--   IF (TO_CHAR(SYSDATE, 'D') = 1) THEN
--      RAISE_APPLICATION_ERROR(-20001,'Tabelul nu se poate actualiza Duminica!');  
--   ELSIF (TO_CHAR(SYSDATE, 'D') = 7) THEN
--      RAISE_APPLICATION_ERROR(-20001,'Tabelul nu se poate actualiza Sambata!');
--   ELSIF ((TO_CHAR(SYSDATE, 'D') = 6) AND (TO_CHAR(SYSDATE,'HH24') NOT BETWEEN 8 AND 16)) THEN
--      RAISE_APPLICATION_ERROR(-20001,'Tabelul nu se poate actualiza vinerea inafara orelor 8:00-16:00');
--   ELSIF (TO_CHAR(SYSDATE,'HH24') NOT BETWEEN 8 AND 20) THEN
--      RAISE_APPLICATION_ERROR(-20001,'Tabelul nu se poate actualiza in timpul saptamanii inafara orelor 8:00-20:00');
--   END IF;
--END;
--
--
--
--TRIGGER cerinta_11
--   BEFORE UPDATE OF status ON Facturi
--   FOR EACH ROW
--DECLARE
--v_sold_curent Informatii_Bancare.sold_curent%TYPE;
--BEGIN
--
--   IF :NEW.status = 'Platit' THEN
--      SELECT sold_curent
--      INTO v_sold_curent
--      FROM Informatii_Bancare
--      WHERE cod_client = :NEW.cod_client;
--   
--      IF v_sold_curent < :NEW.total THEN
--         RAISE_APPLICATION_ERROR(-20001, 'Clientul nu dispune de suficienti bani pentru a plati factura!');
--      END IF;
--    END IF;
--    
--    EXCEPTION   --pentru cazul in care clientul nu are inserare in informatii_bancare
--       WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20001, 'Clientul nu are informatiile bancare setate!');
--END;
--
--
--
--TRIGGER cerinta_12
--   BEFORE CREATE OR DROP OR ALTER ON SCHEMA
--DECLARE
--v_operation VARCHAR(30) := SYS.SYSEVENT;
--v_table_name VARCHAR2(30) := SYS.DICTIONARY_OBJ_NAME;
--v_user VARCHAR(50) := SYS.LOGIN_USER;
--BEGIN
--   IF v_user != 'SYSTEM' THEN
--      IF v_operation = 'CREATE' THEN
--         RAISE_APPLICATION_ERROR(-20001, 'Nu aveti dreptul sa creati tabele noi! Tabelul ' || v_table_name || ' nu a fost creat.');
--      ELSIF v_operation = 'ALTER' THEN
--         RAISE_APPLICATION_ERROR(-20001, 'Nu aveti dreptul sa modificati tabele! Tabelul ' || v_table_name || ' nu a fost modificat.');
--      ELSIF v_operation = 'DROP' THEN
--         RAISE_APPLICATION_ERROR(-20001, 'Nu aveti dreptul sa stergeti tabele! Tabelul ' || v_table_name || ' nu a fost sters.');
--      END IF;
--   END IF;
--END;

END pachet_cerinta_13;