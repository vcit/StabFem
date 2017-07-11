% Matlab interface for GlobalFem
%
%   (set of programs in Freefem to perform global stability calculations in hydrodynamic stability)
%  
%  Demonstration script for the test-case of a cylindrical object in a tube
%
% Version 2.0 by D. Fabre , june 2017


%close all;
global ff ffdir ffdatadir sfdir 
ff = '/usr/local/ff++/openmpi-2.1/3.55/bin/FreeFem++-nw -v 0'; %% Freefem command with full path 
ffdatadir = './DATA_FREEFEM_DISKINTUBE';
sfdir = '../SOURCES_MATLAB'; % where to find the matlab drivers
ffdir = '../SOURCES_FREEFEM/'; % where to find the freefem scripts

addpath(sfdir);

% 
Re = 200;
if(exist([ ffdatadir '/CHBASE/chbase_Re' num2str(Re) '.txt'])==2)
    disp(['base flow and adapted mesh for Re = ' num2str(Re) ' already computed']);
    if (exist('baseflow')==0); % if the data are present but the variables were cleared
    mesh=importFFmesh('mesh.msh');
    baseflow =importFFdata(mesh,[ ffdatadir '/CHBASE/chbase_Re' num2str(Re) '.ff2m']);
    end
else
    disp('computing base flow and adapting mesh')
   
    baseflow = FreeFem_Init('meshInit_DiskInTube.edp') 
    Re_start = [10 , 100 , 200]; % values of Re for progressive increasing up to end
    for Rei = Re_start
        baseflow=FreeFem_BaseFlow(baseflow,Rei) 
        baseflow=FreeFem_Adapt(baseflow)
    end
    
 % optional : adapting mesh on eigenmode structure as well      
 [ev,eigenmode] = FreeFem_Stability(baseflow,200,1,0.021+1.771i,1)
 [baseflow,eigenmode]=FreeFem_Adapt(baseflow,eigenmode);  


baseflow.mesh.xlim=[-1,3]; %x-range for plots
plotFF(baseflow,'mesh');
plotFF(baseflow,'u0');  

end

tit = 1;

while(tit~=0)

disp('Type of computation required : ')
disp('   1 -> spectrum and exploration of eigenmodes for a given Re and m');
disp('   2 -> stability curves for a range of Re' );
disp('   3 -> mode + adjoint + sensitivity');
disp('   4 -> base flow Drag as function of Re'); 
disp('   5 -> coefficients of amplitude equation from weakly nonlinear analysis'); 
disp('   0 -> exit');
tit=myinput(' choice ?',1); 

switch tit
    case(1)
        % To plot spectrum and allow to click on modes to plot eigenmodes
   FreeFem_Spectrum_Exploration(baseflow);

    case(2)
    disp('Computing stability branches in the range Re = [120-220] for the fist two branches');
    % stability calculations with loop over Re

    % Unsteady mode branch
    if(exist('EVI')==0) 
        Re_RangeI = [190:10:220];
        %guessI = -.43+2.06i; % starting point for Re=120
        guessI = 1.813i;
        EVI = FreeFem_Stability_LoopRe(baseflow,Re_RangeI,1,guessI,1,'Branch1.txt');
    else
%        data = importata(
    end
    % Steady mode branch
    if(exist('EVS')==0)
        Re_RangeS = [120:10:150];
        EVS = FreeFem_Stability_LoopRe(baseflow,Re_RangeS,1,-0.123,1,'Branch2.txt');
    end
    figure(11);
    subplot(2,1,1);
    plot(Re_RangeS,real(EVS),'-*b',Re_RangeI,real(EVI),'-*r')
    title('growth rate Re(sigma) vs. Reynolds ; unstready mode (red) and steady mode (blue)')
    subplot(2,1,2);
    plot(Re_RangeS,imag(EVS),'-*b',Re_RangeI,imag(EVI),'-*r')
    title('oscillation rate Im(sigma) vs. Reynolds')

 case(3)
    disp(['adjoint and structural sensitivity']);
    Re = myinput('Enter Reynolds number : ',200);  
    m = myinput('Enter wavenumber m : ',1);  
    shift = myinput('Enter shift (complex)  : ',0.03+1.78i);
    baseflow = FreeFem_BaseFlow(baseflow,Re);
    baseflow.mesh.xlim=[-1 3]; % xrange fixed in baseflow.mesh ; inherited by modes
    
    if(exist('eigenmode')==0)
        [ev,eigenmode]=FreeFem_Stability(baseflow,Re,m,shift,1);
    end
    eigenmode.plottitle=['Direct eigenmode with sigma = ',num2str(eigenmode.sigma)]; 
    plotFF(eigenmode,'ux1',1);
    
    if(exist('eigenmodeA')==0)
        [evA,eigenmodeA]=FreeFem_Stability(baseflow,Re,m,shift,1,'A');
    end
    eigenmodeA.plottitle=['Adjoint eigenmode with sigma = ',num2str(eigenmodeA.sigma)]; 
    plotFF(eigenmodeA,'ux1',1);
    
    wavemaker.mesh = eigenmode.mesh;
    wavemaker.plottitle = 'structural sensitivity';
    wavemaker.xlim = [-1,3];
    wavemaker.sensitivity=abs(eigenmode.ux1).*abs(eigenmodeA.ux1)+abs(eigenmode.ur1).*abs(eigenmodeA.ur1)+abs(eigenmode.ut1).*abs(eigenmodeA.ut1);
    plotFF(wavemaker,'sensitivity');
     
    
    case(4)

    % base flow characteristics with loop over Re
    Re_Range = [120:10:220];

    if(exist('Drag_branch')==0)% to save time if already computed
    Drag_branch = [];
    for Re = Re_Range
        baseflow=FreeFem_BaseFlow(baseflow,Re);
        Drag_branch = [Drag_branch,baseflow.Drag];
    end
    end
    
    figure(12);
    plot(Re_Range,Drag_branch);
    xlabel('Re');
    ylabel('Fx');
    title('Base flow drag as function of Re');
    
    
    
    
     case(5)
        Rec = 133.28;
        m = 1;
        disp('Computing coefficients of the weakly nonlinear amplitude equation');
        disp('NB : at the moment this will work only for steady, m=1 bifurcation');
        disp(['Rec = ', num2str(Rec)]);
        baseflow=FreeFem_BaseFlow(baseflow,Rec);
        [evD,eigenmodeD]=FreeFem_Stability(baseflow,Rec,m,0,1);
        eigenmodeD
        [evA,eigenmodeA]=FreeFem_Stability(baseflow,Rec,m,0,1,'A');
        eigenmodeA
        wnl = FreeFem_WNL(baseflow)
        
    % plot 'linear' parts of the results on the drag/re and sigma/re curves
        
        ReWa = [Rec-20 Rec+20]; 
        DWa  = wnl.Drag0+wnl.Drageps/Rec^2*(ReWa-Rec);
        ReWb = Rec+ [0 :0.01 :1].^2*30; 
        DWb  = wnl.Drag0+(wnl.Drageps+real(wnl.DragAAs*wnl.lambdaA/wnl.muA))/Rec^2*(ReWb-Rec);
        figure(12);hold on;
        plot(ReWa,DWa,'--b',ReWb,DWb,'--r');
         
        EVSW = wnl.eigenvalue+wnl.lambdaA/Rec^2*(ReWa-Rec);
        figure(11);subplot(2,1,1);
        hold on;
        plot(ReWa,real(EVSW),'--');
        
        
        figure(13);
        % we try epsilon and epsilonprime (cf. Gallaire et al, FDR 2017, and Tchoufag et al.)
        LiftA_epsilon = sqrt(abs(wnl.lambdaA/wnl.muA).*(1/Rec-1./ReWb)); 
        LiftA_epsilonprime = sqrt(abs(wnl.lambdaA/wnl.muA).*(ReWb-Rec)/Rec^2);
        plot(ReWb,LiftA_epsilon,'b-',ReWb,LiftA_epsilonprime,'b--');
       title('Lift force as function of Re (WNL expansions ; epsilon and epsilon'' scalings)');
        
        
    case(0)
    disp('Goodbye ! hope you had fun :)');
end %switch

end %while

%TRUCS A REGLER
% adaptmesh on adjoint
% reglage des iso niveaux
