library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.all;

entity avs_source is
    generic (
        G_PACKET_SIZE       : natural := 4;
        G_VALID_PROB        : real := 0.5;
        G_FILE_TEST_VECTORS : string := "input.txt";
        G_DATA_FORMAT       : string := "bin"
    );
    port (
        clk     : in  std_logic;
        reset   : in  std_logic;
        data    : out std_logic_vector;
        ready   : in  std_logic;
        valid   : out std_logic;
        last    : out std_logic
    );
end avs_source;

architecture Test of avs_source is
    signal c_packet_data : natural range 0 to G_PACKET_SIZE-1;
    signal r_rand_valid  : std_logic;
    signal r_done_transmitting : std_logic;
begin
    valid <= r_rand_valid;

    process(reset, clk)
        file f_test_vectors     : text open read_mode is G_FILE_TEST_VECTORS;
        variable v_input_line   : line;
        variable v_test_vector  : std_logic_vector(data'range);
        variable seed1          : positive;
        variable seed2          : positive;
        variable rand           : real;
        variable started : std_logic := '0';
    begin
        if (reset = '1') then
            c_packet_data <= 0;
            data(data'range) <= (others => '0');
            r_rand_valid <= '0';
            last <= '0';
            r_done_transmitting <= '0';

            seed1 := 123;
            seed2 := 456;

            if started='0' then
                readline(f_test_vectors, v_input_line);
                if G_DATA_FORMAT="bin" then
                    read(v_input_line, v_test_vector);
                elsif G_DATA_FORMAT="hex" then
                    hread(v_input_line, v_test_vector);
                else
                    assert false report "Invalid data format" severity error;
                end if;
                data <= v_test_vector;
                started := '1';
            end if;
        elsif (rising_edge(clk)) then

            if (r_done_transmitting = '0') then
                uniform(seed1, seed2, rand);
                if (rand<G_VALID_PROB) then
                    r_rand_valid <= '1';
                else
                    r_rand_valid <= '0';
                end if;
            else
                r_rand_valid <= '0';
            end if;

            if (ready = '1' and r_rand_valid = '1') then

                if (endfile(f_test_vectors)) then
                    r_done_transmitting <= '1';
                end if;

                if (not endfile(f_test_vectors)) then
                    readline(f_test_vectors, v_input_line);
                    if G_DATA_FORMAT="bin" then
                        read(v_input_line, v_test_vector);
                    elsif G_DATA_FORMAT="hex" then
                        hread(v_input_line, v_test_vector);
                    else
                        assert false report "Invalid data format" severity error;
                    end if;
                    data <= v_test_vector;
                else
                    r_rand_valid <= '0';
                end if;

                if (c_packet_data < G_PACKET_SIZE - 1) then
                    if (c_packet_data = G_PACKET_SIZE - 2) then
                        last <= '1';
                    end if;
                    c_packet_data <= c_packet_data + 1;
                else
                    c_packet_data <= 0;
                    last <= '0';
                end if;
            end if;

        end if;
    end process;

end Test;
