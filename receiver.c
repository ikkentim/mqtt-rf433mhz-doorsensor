#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>
#include "avr-uart/uart.h"
#include "rcswitch-avr/RCSwitch.h"

int main() {
    uart_init(UART_BAUD_SELECT(9600, F_CPU));
    enableReceive();

    uart_putc('S');

    DDRB |= _BV(PB5);//B5 out

    int stat = 0;
    for(;;) {
        if(available()) {
            uart_putc('X');

            long value = nReceivedValue;
            uart_putc((value >> 24)& 0xff);
            uart_putc((value >> 16)& 0xff);
            uart_putc((value >> 8)& 0xff);
            uart_putc((value >> 0)& 0xff);

            resetAvailable();
            stat+=5;
        }

        if(stat > 0)
            PORTB |= _BV(PB5);
        else
            PORTB &= ~_BV(PB5);

        if(stat > 0)
        stat--;

        _delay_ms(50);
    }
}
