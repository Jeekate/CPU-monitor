%% Gmeter

clear
%fit = 1-exp(-a*b*x)/sqrt(1-a^2)*sin(b*sqrt(1-a^2)*x+atan(sqrt(1-a^2)/a))
zeta = 0.4733;
wn = 13.14;

sys_meter = tf([wn^2*2.5],[1, 2*zeta*wn, wn^2]); 
step(sys_meter)