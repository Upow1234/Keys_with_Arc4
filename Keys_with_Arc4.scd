// two arc led display types: value and LFO

//control detune amount

//add tuning on the fly


(

//synth
SynthDef("keys", {arg freq = 50, gate = 1, attack = 0.5, decay = 1, sustain = 0.75, release = 1, cutoff, resonance, filterLFOspeed = 0.1, filterLFOdepth = 0;

	var freq1 = freq;
	var freq2 = freq * 1.001;
	var freq3 = freq * 1.003;
	var freq4 = freq;

	var w2_1 = Klang.ar(`[[freq1, freq1 * 3, freq1 * 5, freq1 * 7], [1, 0.19, 0.03, 0.01]]);
	var w4_2 = Klang.ar(`[[freq2, freq2 * 2, freq2 * 3, freq2 * 5, freq2 * 7], [1, 0.55, 0.18, 0.03, 0.01]]);
	var w2_3 = Klang.ar(`[[freq3, freq3 * 3, freq3 * 5, freq3 * 7], [1, 0.19, 0.03, 0.01]]);
	var w3_4 = Klang.ar(`[[freq4, freq4 * 2, freq4 * 4, freq4 * 6, freq4 * 8, freq4 * 10, freq4 * 12], [1, 0.39, 0.08, 0.04, 0.02, 0.01, 0.01]]);

	var env1 = EnvGen.kr(Env([0, 1, 0.5, 0], [0.01 * attack, 0.5, 0.2 * release], releaseNode: 1), gate, (0.9 * 0.1), doneAction: 2);
	var env2 = EnvGen.kr(Env([0, 1, 0.5, 0], [0.01 * attack, 0.5, 0.1 * release], releaseNode: 1), gate, (0.8 * 0.1));
	var env3 = EnvGen.kr(Env([0, 1, 0.5, 0], [0.01 * attack, 0.5, 0.1 * release], releaseNode: 1), gate, (0.35 * 0.1));
	var env4 = EnvGen.kr(Env([0, 1, 0.5, 0], [0.5 * attack, 0.5, 0.11 * release], releaseNode: 1), gate, (0.77 * 0.1));

	var output = ((((w2_1  * env1) + (w4_2 * env2)) + (w2_3 * env3)) + (w3_4 * env4));

	//env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: Done.freeSelf);

	Out.ar([0, 1], RLPF.ar(output, 20000, resonance, 0.5));

}).add;

s.waitForBoot({

	//faint led array for right side of grid, second value is led level
	var faint = Array.fill(64, 2);


	~grid128 = MonoM.new("/monome", 0);
	~arc4 = Arc.new("/monome", 0);

	//just sixth is 1.6667
	//~notes = [ 1, 1.125, 1.25, 1.3333, 1.5, /*set to equal temperment major sixth*/1.68179, 1.875, 2];
	~notes = [ 1, 1.111, 1.25, 1.3333, 1.5, /*set to equal temperment major sixth*/1.6665, 1.875, 2];

	//array to hold all playing synths
	~voiceVariables = Array.fill(64, nil);
	~voiceStatus = Array.fill(64, 0);

	//arc left encoders and right encoders selection index
	~selectionLeft = 0;
	~selectionRight = 1;

	//grid led array for left side of grid
	~gridLeft = Array.fill(64, 0);

	~pwLfoSpeed = 1;

	~selectionLeft;
	~selectionRight;
	~leftLed;
	~rightLed;

	~synthsGroup = Group.new;


	~grid128.usePort(16139);
	~arc4.usePort(16159);

	//set right side of grid to faint led
	~grid128.levmap(8, 0, faint);

	//grid functions
	OSCFunc.newMatching(
		{ arg message, time, addr, recvPort;

			//index to add synth to ~voiceVariables, message[1] range is moved from
			//8-15 to 0-7 with "- 8"
			var key = (message[1] - 8) + (message[2] * 8);
			//the key of the diatonic keyboard: (0 = C), (1 = C#)...
			var root = 7.midicps;
			//used to transpose the scale in ~notes up all octaves
			var octave = [128, 64, 32, 16, 8, 4, 2, 1];
			//faint led array for grid

			if(message[1] >= 8, {

				switch(message[3], 1, {
					s.makeBundle(nil, {
						//turns playing key led on
						faint[key] = 15;

						~grid128.levmap(8, 0, faint);

						//stores Synth in ~voiceVariable, picks note by taking grid x down to the range of 0-7 for accessing ~notes array, then transposes the note by octaves with the local octave array based on the input of y (the octave array is inputed (inverted?) so 7 is the lowest octave and 0 is the highest)

						~voiceVariables[key] = Synth("keys", [\freq, ((~notes[message[1] - 8] * root) * octave[message[2]]), \attack, ~pairs[0][0].currentValue, \decay, ~pairs[0][1].currentValue, \sustain, ~pairs[1][0].currentValue, \release, ~pairs[1][1].currentValue, \cutoff, ~pairs[2][0].currentValue, \resonance, ~pairs[2][1].currentValue, \filterLFOspeed, ~pairs[3][0].currentValue, \filterLFOdepth, ~pairs[3][1].currentValue], ~synthsGroup);

						s.sync;
					});
				}, 0, {
					s.makeBundle(nil, {
						~voiceVariables[key].release;

						faint[key] = 2;

						~grid128.levmap(8, 0, faint);
						s.sync;
					});

				});
			});


			//pageLeft selection

			if((message[1] == 0) && (message[3] == 1), {
				var x = message[1];
				var y = message[2];

				~selectionLeft = x + (y * 2);
				~leftLed = x + (y * 8);
				~gridLedUpdate.value();

				postln("selectionLeft = " + ~selectionLeft);

				~updateArcLeds.value(0, ~pairs[~selectionLeft][0].arcLedValue);
				~updateArcLeds.value(1, ~pairs[~selectionLeft][1].arcLedValue);

			});

			if((message[1] == 2) && (message[3] == 1), {
				var x = (message[1] - 1);
				var y = message[2];

				~selectionLeft = x + (y * 2);
				~leftLed = (x + 1) + (y * 8);
				~gridLedUpdate.value();

				postln("selectionLeft = " + ~selectionLeft);

				~updateArcLeds.value(0, ~pairs[~selectionLeft][0].arcLedValue);
				~updateArcLeds.value(1, ~pairs[~selectionLeft][1].arcLedValue);
			});

			//pageRight selection

			if((message[1] == 1) && (message[3] == 1), {
				var x = (message[1] - 1);
				var y = message[2];

				~selectionRight = x + (y * 2);
				~rightLed = (x) + (y * 8);
				~gridLedUpdate.value();

				postln("selectionRight = " + ~selectionRight);

				~updateArcLeds.value(2, ~pairs[~selectionRight][0].arcLedValue);
				~updateArcLeds.value(3, ~pairs[~selectionRight][1].arcLedValue);

			});

			if((message[1] == 3) && (message[3] == 1), {
				var x = (message[1] - 2);
				var y = message[2];

				~selectionRight = x + (y * 2);
				~rightLed = (x + 1) + (y * 8);
				~gridLedUpdate.value();

				postln("selectionRight = " + ~selectionRight);

				~updateArcLeds.value(2, ~pairs[~selectionRight][0].arcLedValue);
				~updateArcLeds.value(3, ~pairs[~selectionRight][1].arcLedValue);

			});

	}, "/monome/grid/key");

	//function to update grid leds

	~gridLedUpdate = {
		~gridLeft.fill(0);

		//selection leds
		~gridLeft[~leftLed] = 15;
		~gridLeft[~leftLed + 1] = 15;


		~gridLeft[~rightLed] = 5;
		~gridLeft[~rightLed + 1] = 5;


		//update left sides
		~grid128.levmap(0, 0, ~gridLeft);

	};

	//initialize grid leds

	//~grid128.ledall(0);

	~leftLed = 0;
	~rightLed = 2;

	~gridLedUpdate.value;

	OSCFunc.newMatching(
		{ arg message, time, addr, recvPort;

			var arcFunctions = {arg name, messageOne, messageTwo;
				name.change(messageTwo);
				name.sendChange;
				~updateArcLeds.value(messageOne, name.arcLedValue);
			};


			switch(message[1], 0, {
				arcFunctions.value(~pairs[~selectionLeft][0], 0, message[2]);
			}, 1, {
				arcFunctions.value(~pairs[~selectionLeft][1], 1, message[2]);
			}, 2, {
				arcFunctions.value(~pairs[~selectionRight][0], 2, message[2]);
			}, 3, {
				arcFunctions.value(~pairs[~selectionRight][1], 3, message[2]);
			});

	}, "/monome/enc/delta");


	~pairs = [
		[ArcParameter.new("Attack", 0.01, 50, 10, 2, 0.1, ~synthsGroup, \attack, 0),
			ArcParameter.new("Decay", 0.01, 15, 50, 2, 0.5, ~synthsGroup, \decay, 0)],
		[ArcParameter.new("Sustain", 0, 1, 50, 2, 1, ~synthsGroup, \sustain, 0),
			ArcParameter.new("Release", 0.01, 50, 10, 2, 0.1, ~synthGroup, \release, 0)],
		[ArcParameter.new("Cutoff", 1, 8, 50, 2, 8, ~synthsGroup, \cutoff, 0),
			ArcParameter.new("Resonance", 0.1, 1, 50, 2, 1, ~synthsGroup, \resonance, 0)],
		[ArcParameter.new("Filter LFO Speed", 0.01, 500, 50, 2, 0.01, ~synthsGroup, \filterLFOspeed, 0), ArcParameter.new("Filter LFO Depth", 0, 0.95, 200, 2, 0, ~synthsGroup, \filterLFOdepth, 0)]];

	for(0, 63, {arg i;
		~voiceVariables[i] = Synth.basicNew("keys");
	});

	~updateArcLeds = {arg encoderNumber, ledValue;

		var encoderTemporaryArray = Array.fill(64, { arg index;
			if(index <= ledValue, { 15 }, { 0 });
		});

		~arc4.ringmap(encoderNumber, encoderTemporaryArray);

	};

});

)

~voiceVariables[32].isPlaying
~voiceVariables[32].isRunning
~voiceVariables[32].release

~pairs[0][0].currentValue.postln;

