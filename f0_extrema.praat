# f0_extrema.praat
# ----------------
#
# Pablo Arantes <pabloarantes@protonmail.com>
#
# = Version =
# [0.9.2] - 2019-07-31
# See CHANGELOG.md for a complete version history.
#
# = Purpose =
# Find peaks and valleys, collectivelly called extreme points, in f0 and
# f0 velocity contours.
#
# = Input =
# In "Multiple files" mode, a folder containing any number of Pitch
# files and another folder with corresponding TextGrid files with
# user-added segmentation.
# 
# In "Single file" mode, one Pitch file and its corresponding TextGrid.
# The complete path and file name (extension included) of Pitch and
# TextGrid should be informed by the user in the GUI menu: "Pitch path"
# and "Grid_path" fields.
# 
# = Output =
# In "Multiple files", the script outputs a report listing all extreme
# points for each Pitch-TextGrid pair in the folders defined by the user.
# The full path and name of the report file should be specified at the
# "Report" field in the script initial form.
#
# In "Single file" mode, the script outputs two Sound objects and one
# TextGrid object. The Sound objects contain two channels, the first one
# is the smooth f0 contour and the second the f0 velocity contour. One
# Sound object has the values in Hz and the other in the OctaveMedian
# scale. The TextGrid has three tiers: boundaries in the interval range
# defined by the user; extreme points in f0 contour; extreme points in
# f0 velocity contour.
#
# To better view the contours in the Sound objects, go to View > Sound
# scaling > Scaling strategy and choose "by window and channel".
#
# Copyright (C) 2008-2019 Pablo Arantes
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# A copy of the GNU General Public License is available at
# <http://www.gnu.org/licenses/>.

form Extreme points in f0 contours
	comment Multiple files: provide path to folders containing Pitch and TextGrid files.
	comment Single file: provide path and name of Pitch and TextGrid files.
	choice Mode: 1
		button Multiple files
		button Single file
	sentence Pitch_path /path/to/pitch
	sentence Grid_path /path/to/grids
	sentence Report /path/to/report/name.txt
	positive Smooth_(Hz) 3
	real Median 0 (= estimate from Pitch object)
	natural Tier 1
	natural left_Interval_range 1
	natural right_Interval_range 5
endform

if mode = 1
	files_ext = Create Strings as file list: "files", pitch_path$ + "*.Pitch"
	files = Replace all: ".Pitch", "", 0, "literals"
	nfiles = Get number of strings
	removeObject: files_ext
else
	nfiles = 1
endif

for file to nfiles
	
	# ---- TextGrid ----
	#
	# - Read TextGrid
	# - Do some testing
	#	- Is variable 'Tier' valid?
	#	- Is 'Tier' an interval tier?
	#	- Is the interval range valid?
	# - Erase intervals outside the user-specified range

	if mode = 1
		file$ = object$[files, file]
		grid$ = grid_path$ + file$ + ".TextGrid"
	else
		grid$ = grid_path$
	endif

	if fileReadable(grid$)
		raw_grid = Read from file: grid$
	else
		exitScript: "TextGrid file ", grid$, " not readable."
	endif

	ntiers = Get number of tiers
	if tier > ntiers
		exitScript: "TextGrid has ", ntiers, " tiers. User specified tier ", tier, "." 
	endif

	test_tier = Is interval tier: tier
	if test_tier
		work_tier = Extract one tier: tier
	else
		exitScript: "Tier ", tier, " has to be an interval tier."
	endif

	if left_Interval_range > right_Interval_range
		exitScript: "End interval has to be greater than start interval."
	endif

	# 'Time decimals' has to be at least 19 to be precise enough
	# for the 'Extend time' function
	tab = Down to Table: "no", 20, "no", "no"
	nint = object[tab].nrow
	if right_Interval_range > nint
		exitScript: "Selected tier has ", nint, " non-empty interals. User specified end interval greater than that."
	endif

	# Start and end times of analysis window
	start = object[tab, left_Interval_range, 1]
	end = object[tab, right_Interval_range, 3]

	# Only keep the intervals in the range defined by the user 
	selectObject: work_tier
	grid = Extract part: start, end, "yes"
	Extend time: start, "Start"
	Extend time: object[raw_grid].xmax - end, "End"

	# ---- f0 surface contour ----
	#
	# - Read Pitch raw file
	# - Perform constant extrapolation at boudaries
	# - Smooth contour
	# - Pitch -> Sound conversion
	# - Scale conversion (Hz -> OMe)
	# - Find extreme points

	if mode = 1
		file$ = object$[files, file]
		pitch$ = pitch_path$ + file$ + ".Pitch"
	else
		pitch$ = pitch_path$
	endif

	raw_pitch = Read from file: pitch$
	filename$ = selected$("Pitch")

	# Define median f0 value
	if median > 0
		median_f0 = median
	elsif median = 0
		median_f0 = Get quantile: 0.0, 0.0, 0.50, "Hertz"
	else
		exitScript: "Median f0 has to be a positive value."
	endif

	# Interpolate at boundaries
	@extrapolation: raw_pitch
	interp_pitch =	extrapolation.out_pitch

	smoothed_pitch = Smooth: smooth
	mat = To Matrix
	smoothed_sound = To Sound
	Rename: "smoothed_contour_hz"

	# Transform to OctaveMedian (OMe) scale
	ome_sound = Copy: "smoothed_contour_ome"
	Formula: "if self <> 0 then log2(self / median_f0) else 0 fi"

	# Find local minima (L points)
	l_points = To PointProcess (extrema): 1, "no", "yes", "Sinc70"
	Rename: "L_extremes"
	# Find local maxima (H points)
	selectObject: ome_sound
	h_points = To PointProcess (extrema): 1, "yes", "no", "Sinc70"
	Rename: "H_extremes"

	# ---- f0 velocity ----

	# Get f0 velocity (Hz/s) from hertz f0 contour
	selectObject: smoothed_sound
	hz_vel = Copy: "hz_vel"
	Formula: "if col < ncol then (self[col+1] - self[col])/dx else self[col - 1] fi"

	# Get f0 velocity (8va/s) from smoothed f0 contour
	selectObject: ome_sound
	ome_vel = Copy: "ome_vel"
	Formula: "if col < ncol then (self[col+1] - self[col])/dx else self[col - 1] fi"

	# Find local minima (F points)
	f_points = To PointProcess (extrema): 1, "no", "yes", "Sinc70"
	Rename: "F_extremes"

	# Find local maxima (R points)
	selectObject: ome_vel
	r_points = To PointProcess (extrema): 1, "yes", "no", "Sinc70"
	Rename: "R_extremes"

	# ---- Assemble output TextGrid ----

	# Create TextGrid tiers: f0 and f0 velocity
	@pointp_to_table: l_points, start, end, "L"
	l_tab = pointp_to_table.out_tab
	@pointp_to_table: h_points, start, end, "H"
	h_tab = pointp_to_table.out_tab
	@pointp_to_table: f_points, start, end, "F"
	f_tab = pointp_to_table.out_tab
	@pointp_to_table: r_points, start, end, "R"
	r_tab = pointp_to_table.out_tab
	
	# TextGrid tiers creation
	f0_tier = Create TextGrid: object[ome_sound].xmin, object[ome_sound].xmax, "f0", "f0"
	f0vel_tier = Create TextGrid: object[ome_sound].xmin, object[ome_sound].xmax, "f0-velocity", "f0-velocity"

	@write_ptier: l_tab, f0_tier
	@write_ptier: h_tab, f0_tier
	@write_ptier: f_tab, f0vel_tier
	@write_ptier: r_tab, f0vel_tier

	selectObject: grid, f0_tier, f0vel_tier
	output_grid = Merge
	Rename: filename$ + "_extr"

	# ---- Data collection ----

	selectObject: l_tab, h_tab, f_tab, r_tab
	all_tab = Append

	Insert column: 1, "file"
	Insert column: 2, "position"
	Insert column: 3, "label"
	Append column: "value"
	Append column: "value_hz"
	Append column: "phase"
	Append column: "global_phase"

	for row to object[all_tab].nrow
		time_extreme = object[all_tab, row, "time"]
		type$ = object$[all_tab, row, "type"]
		if (type$ = "L") or (type$ = "H")
			value = object(ome_sound, time_extreme, 0)
			value_hz = object(smoothed_sound, time_extreme, 0)
		else
			value = object(ome_vel, time_extreme, 0)
			value_hz = object(hz_vel, time_extreme, 0)
		endif
		selectObject: grid
		interval = Get interval at time: 1, time_extreme
		interval_start = Get start time of interval: 1, interval
		interval_end = Get end time of interval: 1, interval
		phase = (interval - 1) + ((time_extreme - interval_start) / (interval_end - interval_start))
		global_phase = (time_extreme - start) / (end - start)
		label$ = Get label of interval: 1, interval
		selectObject: all_tab
		Set string value: row, "file", filename$
		Set numeric value: row, "position", interval - 1
		Set string value: row, "label", label$
		Set string value: row, "value", fixed$(value, 3)
		Set string value: row, "value_hz", fixed$(value_hz, 1)
		Set string value: row, "phase", fixed$(phase, 3)
		Set string value: row, "global_phase", fixed$(global_phase, 3)
	endfor
	Sort rows: "time"
	Remove column: "time"
	all_tab[file] = all_tab

	# ---- Clean up ----

	removeObject: raw_grid, work_tier, grid 
	removeObject: smoothed_pitch
	removeObject: raw_pitch, interp_pitch, mat
	removeObject: l_points, h_points, f_points, r_points, tab
	removeObject: l_tab, h_tab, f_tab, r_tab
	removeObject: f0_tier, f0vel_tier

	if mode = 1
		selectObject: output_grid
		output_grid$ = selected$("TextGrid")
		Save as text file: grid_path$ + output_grid$ + ".TextGrid"
		removeObject: output_grid
	else
		selectObject: ome_sound, ome_vel
		Combine to stereo
		Rename: filename$ + "_OMe"
		selectObject: smoothed_sound, hz_vel
		Combine to stereo
		Rename: filename$ + "_hz"
		removeObject: all_tab
	endif
	removeObject: hz_vel, ome_vel, ome_sound, smoothed_sound
endfor

if mode = 1
	selectObject: all_tab[1]
	for file from 2 to nfiles
		plusObject: all_tab[file]
	endfor
	all_files = Append
	Save as tab-separated file: report$
	for file to nfiles
		removeObject: all_tab[file]
	endfor
	removeObject: files, all_files
	writeInfoLine: "Done"
	appendInfoLine: "--"
	appendInfoLine: "Run on ", date$()
endif

# ---- Procedures ----

procedure extrapolation: .pitch
# Constant extrapolation of values before the first
# and last points of a Pitch object.
# Applied if there is an unvoiced gap between start of
# contour and first voiced sample.
#
# = Arguments =
# .pitch [num]: Pitch object ID
#
# = Output =
# .out_pitch [num]: interpolated Pitch object ID

	selectObject: .pitch
	.start = Get start time
	.end = Get end time
	.frames = Get number of frames
	.step = Get time step
	.sample_1 = Get time from frame number: 1
	.sample_n = Get time from frame number: .frames
	.min_f0 = Get minimum: 0.0, 0.0, "Hertz", "Parabolic"
	.max_f0 = Get maximum: 0.0, 0.0, "Hertz", "Parabolic"
	.ptier = Down to PitchTier
	if (.sample_1 - .start) > 0.04
		selectObject: .ptier
		Add point: (.start + .step), object(.ptier, .sample_1)
	endif
	if (.end - .sample_n) > 0.04
		Add point: (.end - .step), object(.ptier, .sample_n)
	endif
	.out_pitch = To Pitch: .step, floor(.min_f0 / 10) * 10, ceiling(.max_f0 / 10) * 10
	removeObject: .ptier
endproc

procedure pointp_to_table: .pointp, .start, .end, .type$
# Convert a PointProcess into a Table keeping only the points
# within the interval defined by .start and .end time points.
#
# = Arguments =
# .pointp [num]: PointProcess ID
# .start [num]: Start time of analysis interval
# .end [num]: End time of analysis interval
# .type$ [char]: Type of extreme value
#
# = Output =
# .out_tab [num]: generated Table object ID

	selectObject: .pointp
	Remove points between: object[.pointp].xmin, .start
	Remove points between: .end, object[.pointp].xmax
	.textt = Up to TextTier: .type$
	.tor = Down to TableOfReal: .type$
	.out_tab = To Table: "type"
	Set column label (label): "Time", "time"
	removeObject: .textt, .tor
endproc

procedure write_ptier: .tab, .ptier
# Assign extreme points on a Table object to a PointTier
#
# = Arguments =
# .tab [num]: Table ID
# .ptier [num]: PointTier ID

	selectObject: .tab
	.npts = object[.tab].nrow
	for .pt to .npts
		.type$ = object$[.tab, .pt, 1]
		.time = object[.tab, .pt, 2]
		selectObject: .ptier
		Insert point: 1, .time, .type$
	endfor
endproc
