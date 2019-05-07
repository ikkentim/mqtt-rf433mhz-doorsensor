#include <avr/io.h>
#include <avr/power.h>
#include <avr/interrupt.h>
#include <avr/sleep.h>
#include <avr/wdt.h>
#include <util/delay.h>

#ifndef CODE_INIT
#  define CODE_INIT 5399
#endif
#ifndef CODE_ON
#  define CODE_ON   5393
#endif
#ifndef CODE_OFF
#  define CODE_OFF  5395
#endif


#define PULSE_LENGTH 650

volatile int status;

void rfinit() {
    DDRB |= _BV(PB4);
    DDRB |= _BV(PB2);
    PORTB &= ~_BV(PB2);
    PORTB &= ~_BV(PB4);
}

#define rftransmit(high, low) { \
    PORTB |= _BV(PB4); \
    _delay_us(PULSE_LENGTH * high); \
    PORTB &= _BV(PB4); \
    _delay_us(PULSE_LENGTH * low); } \

void rfsend(unsigned long code, unsigned int length) {
    PORTB |= _BV(PB2);

    _delay_ms(100);

    for (int nRepeat = 0; nRepeat < 5; nRepeat++) {
        for (int i = length-1; i >= 0; i--) {
            if (code & (1L << i)) {
                rftransmit(3, 1);
            } else {
                rftransmit(1, 3);
            }
        }

        // sync
        rftransmit(1, 65);//was 31
    }

    PORTB &= ~_BV(PB4);
    PORTB &= ~_BV(PB2);
}

int main(void) {
    MCUSR = 0; // reset flags
    PRR = 0b1111;// disable timers, USE, ADC in power reduction register
    ACSR|=_BV(ACD);// turn off analog comparator
    CLKPR=_BV(CLKPCE); CLKPR=3;// change clock prescaler

    rfinit();

    status = 0;

    // disable watchdog
    MCUSR &= ~_BV(WDRF);
    wdt_disable();

    DDRB &= ~_BV(PB3); // set B3 to input(0)
    PORTB |= _BV(PB3);// enable pull-up resistor for B3

    MCUCR |= _BV(ISC00);
    MCUCR &= ~_BV(ISC01);// falling and rising edge

    GIMSK |= _BV(PCIE);// pin change interrupt enable in general interrupt mask register
    PCMSK |= _BV(PCINT3); // enable pin change interrupt for B3

    rfsend(CODE_INIT, 24);

    for(;;) {
        set_sleep_mode(SLEEP_MODE_PWR_DOWN);
        cli();                         //stop interrupts to ensure the BOD timed sequence executes as required
        sleep_enable();
        sleep_bod_disable();           //disable brown-out detection while sleeping (20-25µA)
        sei();                         //ensure interrupts enabled so we can wake up again
        sleep_cpu();                   //go to sleep
        sleep_disable();               //wake up here

        _delay_ms(50); // allow signal to settle

        int open;
        do {
            open = status;
            for(int i=0;i<3;i++) {
            rfsend(open ? CODE_ON : CODE_OFF, 24);
            _delay_ms(250);
            }
        } while(open != status);
    }
}

ISR (PCINT0_vect) {
    status = PINB & _BV(PB3);
}
