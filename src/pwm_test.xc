#include <xs1.h>
#include <timer.h>
#include <assert.h>
#include <stdio.h>
#include <platform.h>
#include <print.h>
#include <xscope.h>
#include <stdlib.h>


#pragma unsafe arrays
#define MODES 8
#define GATES 6

clock clk = XS1_CLKBLK_REF;


port p32 = XS1_PORT_32A;
out buffered port:1 qah = XS1_PORT_1K;
out buffered port:1 qal = XS1_PORT_1L;
out buffered port:1 qbh = XS1_PORT_1M;
out buffered port:1 qbl = XS1_PORT_1N;
out buffered port:1 qch = XS1_PORT_1O;
out buffered port:1 qcl = XS1_PORT_1P;
port hallSensors = XS1_PORT_4C;

int leds[MODES] = {
    0xE0380, // 0b111
    0xE1B80, // 0b001
    0xE0B80, // 0b101
    0xE0F80, // 0b100
    0xE0780, // 0b110
    0xE1780, // 0b010
    0xE1380, // 0b011
    0xE1F80  // 0b000
};

int pwm[MODES] = {// control for switching phase
        0b000000, // All Off
        0b110000, // C Phase Switching 001
        0b000011, // A Phase Switching 101
        0b000011, // A Phase Switching 100
        0b001100, // B Phase Switching 110
        0b001100, // B Phase Switching 010
        0b110000, // C Phase Switching 011
        0b000000  // All Off
};

int pwm2[MODES] = { // control for return phase
        0b000000, // all off
        0b001000, // B phase return 001
        0b001000, // B phase return 101
        0b100000, // C phase return 100
        0b100000, // C phase return 110
        0b000010, // A phase return 010
        0b000010, // A phase return 011
        0b000000  // all off
};

/*
 * pwmtest.xc
 *
 *  Created on: Nov 30, 2014
 *      Author: Kellen
 */

void pwm_handler ( chanend c, chanend c2, out buffered port:1 p, out buffered port:1 p1, out buffered port:1 p2, out buffered port:1 p3, out buffered port:1 p4, out buffered port:1 p5, unsigned port_width) {
  unsigned int duty;
  unsigned int period;
  unsigned int val;
  unsigned int led_counter;
  unsigned int now;

  unsigned int edgetime;


  c :> period;
  c :> duty;
  c2 :> led_counter;


  // check input values
  if(duty>period) {
      printf("ERROR: PWM duty cycle length %d is greater than period %d",duty, period);
      assert(0);
  }
  if(port_width>32) {
      printf("ERROR: port_width %d is greater than the maximum 32",port_width);
  }

  val = (1<<port_width)-1; // generate port value

  //start with the output off
  //get the current port time
  p <: 0 @ now;

  while(1) {


    if(period != duty) { // if not always on
      //obtain time of PWM falling edge
      edgetime = now + duty;
      p @ edgetime <: (!pwm[led_counter] & 0b000001);
      p1 @ edgetime + 30 <: ((pwm[led_counter] >> 1) & 0b000001) | ((pwm2[led_counter] >> 1) & 0b000001) ;
      p2 @ edgetime <: ((!pwm[led_counter] >> 2) & 0b000001);
      p3 @ edgetime + 30 <: ((pwm[led_counter] >> 3) & 0b000001) | ((pwm2[led_counter] >> 3) & 0b000001);
      p4 @ edgetime <: ((!pwm[led_counter] >> 4) & 0b000001);
      p5 @ edgetime + 30 <: ((pwm[led_counter] >> 5) & 0b000001) | ((pwm2[led_counter] >> 5) & 0b000001);

      //output falling edge
    };


    if(duty != 0) { // if not always off
      //obtain time for end of PWM cycle
      now = now + period;

      p @ now <: (pwm[led_counter] & 0b000001);
      p1 @ now - 30 <: ((!pwm[led_counter] >> 1) & 0b000001) | ((pwm2[led_counter] >> 1) & 0b000001);
      p2 @ now <: ((pwm[led_counter] >> 2) & 0b000001);
      p3 @ now - 30 <: ((!pwm[led_counter] >> 3) & 0b000001) | ((pwm2[led_counter] >> 3) & 0b000001);
      p4 @ now <: ((pwm[led_counter] >> 4) & 0b000001);
      p5 @ now - 30 <: ((!pwm[led_counter] >> 5) & 0b000001) | ((pwm2[led_counter] >> 5) & 0b000001);
      //output rising edge
    }

    //select on channelend tests for new data on the channel from the client
    select {
      //this case is taken if the channel has data
      case c :> duty:
        if(duty>period) { // check value
            printf("ERROR: PWM duty cycle length %d is greater than period %d",duty, period);
            assert(0);
        }
        break;
      case c2 :> led_counter:

        break;
      //this case is taken otherwise
      default:
        break;
    }
  }
}



void task1(chanend c, chanend c2){


    int period;
    int duty;
    int led_counter = 0;
    unsigned int i;

    period = 4000;
    duty = 400;
    c <: period;
    c <: duty;

    while(1){
           hallSensors :> i;

           switch (i) {
               case 8:
                   led_counter = 7;
                   break;
               case 15:
                   led_counter = 0;
                   break;
               case 11:
                   led_counter = 6;
                   break;
               case 9:
                   led_counter = 1;
                   break;
               case 13:
                   led_counter = 2;
                   break;
               case 14:
                   led_counter = 4;
                   break;
               case 12:
                   led_counter = 3;
                   break;
               case 10:
                   led_counter = 5;
                   break;
           }
           c2 <: led_counter;
           p32 <: leds[led_counter];
    }
}

int main(void) {
    chan c;
    chan c2;



    par {
       on tile[0]: task1(c, c2);
       on tile[0]: pwm_handler(c, c2, qah, qal, qbh, qbl, qch, qcl, 1);
    }
    return 0;
}
