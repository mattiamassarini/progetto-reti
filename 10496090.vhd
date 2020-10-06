----------------------------------------------------------------------------------
-- PROGETTO DI RETI LOGICHE 2018/2019 - INGEGNERIA INFORMATICA - Professor Fabio Salice
-- 
-- Massarini Mattia - Matricola 825664 Codice persona 10496090
-- Data di consegna 15 Maggio 2019
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;
-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity project_reti_logiche is
  Port (
        i_clk               :in  std_logic;
        i_start             :in  std_logic;
        i_rst               :in  std_logic;
        i_data              :in  std_logic_vector(7 downto 0);
        o_address           :out std_logic_vector(15 downto 0 );
        o_done              :out std_logic;
        o_en                :out std_logic;
        o_we                :out std_logic;
        o_data              :out std_logic_vector(7 downto 0)
        );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
type state is (done,read_x,read_y,read_x0,read_y0,read_mask,write,calculate,init,check_mask,wait_x,wait_y,save,wait_y0,wait_x0);
type vector is array(7 downto 0) of integer range -1024 to 1024;
signal next_state : state;
begin
process(i_rst,i_clk) 
variable inputmask,outputmask : std_logic_vector(7 downto 0) := (others => '0');
variable sum: integer := 0;
variable int_x,int_y,int_x0,int_y0: integer range 0 to 255:= 0;
variable min : integer range 0 to 512 := 512;
variable index : integer range -1 to 19 := 7;
variable distance_array: vector := (-1,-1,-1,-1,-1,-1,-1,-1);

begin
-- se il segnale di reset è ad 1 i segnali e le variabili vengono inizializzate
if(i_rst = '1') then 
        o_done <= '0';
        o_we <= '0';
        o_en <= '1';
        o_address <= (others => '0');
        o_data <= (others => '0');
        min := 512;
        index := 7;
        next_state <= init;
end if;        
if rising_edge(i_clk) then 
    case next_state is
           
        when init =>        if(i_start = '1') then
                                    o_done <= '0';
                                    o_we <= '0';
                                    o_en <= '1';
                                    o_address <= (others => '0');
                                    o_data <= (others => '0');
                                    min := 512;
                                    index := 7;
                                    next_state <= read_mask;
                                   
                            end if;
-- stato per salvare la maschera di ingresso e per assegnare  l'indirizzo 
-- della coordinata x del centroide da valutare
        when read_mask =>   
                            inputmask := i_data;
                            o_address <= std_logic_vector(to_unsigned(17,16));
                            next_state<= wait_x0;
                            
-- stato di attesa                                               
        when wait_x0 =>      
                            next_state<= read_x0;
-- stato per salvare la coordinata x del centroide da valutare in una variabile e
-- per salvare l'indirizzo della coordinata y del centroide da valutare       
        when read_x0 =>     
                            int_x0 := to_integer(unsigned(i_data));
                            o_address <= std_logic_vector(to_unsigned(18,16));
                            next_state<= wait_y0;   
--stato di attesa
        when wait_y0 =>     
                            next_state <= read_y0; 
-- la coordinata y del centroide da valutare è salvata in una variabile                     
        when read_y0 =>     
                            int_y0:= to_integer(unsigned(i_data));
                            next_state <= check_mask;
-- stato di controllo:
-- - se l'indice è -1 il componente ha controllato tutta la maschera di ingresso
--   e si prosegue generando la maschera di uscita nello stato "save"
-- - se l'indice è compreso tra 7 e 0 (estremi compresi), 
--   per ogni bit i-esimo se esso è 1 viene assegnato l'indirizzo 
--   della coordinata x dell'i-esimo centroide in o_address e si prosegue, altrimenti 
--   viene decrementato l'indice e si rimane nello stato corrente.                         
        when check_mask =>   
                            if index = -1 then
                                next_state <= save;
                            elsif inputmask(index) = '1' then
                                o_address <= std_logic_vector(to_unsigned((index*2)+1,16));
                                next_state <= wait_x;
                            else index:= index-1;
                                next_state <=check_mask;    
                            end if;
-- stato di attesa      
        when wait_x => 
                            next_state<= read_x;                                         
-- stato per salvare la coordinata x dell'i-esimo centroide in una variabile
-- e per assegnare l'indirizzo della coordinata y
        when read_x =>      
                            int_x:= to_integer(unsigned(i_data));
                            o_address <= std_logic_vector(to_unsigned((index*2)+2,16));
                            next_state <= wait_y;
                            
-- stato di attesa                         
        when wait_y =>        
                            next_state<=read_y; 

-- stato per salvare la coordinata y dell'i-esimo centroide in una variabile 
        when read_y =>      
                            int_y:= to_integer(unsigned(i_data));
                            next_state <= calculate;
                            
 -- dopo aver salvato le due coordinate viene calcolata la distanza di Manhattan che viene salvata in un array
 -- nella cella i-esima. Se la distanza è minore della distanza minima, quest'ultima viene sovrascritta.
 -- Infine l'indice viene decrementato e si torna nello stato check_mask.                           
        when calculate =>   
                            distance_array(index) :=  (abs(int_x-int_x0)+abs(int_y-int_y0));
                            if min>distance_array(index) and distance_array(index) > -1 then
                                min := distance_array(index);
                            else min := min;
                            end if;
                            index := index-1;
                            next_state<=check_mask;
 
 -- stato che controlla per ogni distanza i-esima dell' i-esimo centroide se esso si trova
 -- a distanza minima dal centroide da valutare. Se è vero, il bit i-esimo viene posto a 1,
 -- altrimenti a 0.
 -- Infine viene assegnato l'indirizzo di memoria su cui salvare la maschera di uscita in o_address 
 -- e il segnale di write enable è portato a 1.                            
        when save =>       
                            for i in 0 to 7 loop
                                if min = distance_array(i) then 
                                        outputmask(i) := '1';
                                else outputmask(i) := '0';
                                end if;
                            end loop;
                            o_address <= std_logic_vector(to_unsigned(19,16));
                            o_we <= '1';
                            next_state <= write;
 
 -- la maschera di uscita è salvata in o_data e il segnale di done è portato a 1 (fine computazione)                           
        when write =>  
                            o_data <= outputmask;
                            o_done <= '1';
                            next_state <= done;
                            
-- il segnale di done rimane alto fino a quando il segnale di start non è stato portato basso, infine il componente torna
-- nello stato di inizializzazione per una successiva computazione.                            
        when done =>        if(i_start = '0') then
                                o_done<='0'; 
                            next_state <= init;
                            end if;                                                               
        end case;
    end if;
end process;

end Behavioral;
