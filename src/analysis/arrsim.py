#!/usr/bin/env python
"""
Simulate microphone array measurement; models BatStack Array.

NOTES:

Note that we wrap white noise outside valid range back into the signal!
This procedure is biased toward lower values; explicitly,
an absolute value operation and modulo are applied.
The abs is natural, but mod causes large signals to appear again
near zero. This is in significant contrast to clipping.

I tend to interchange freely between indexing channels via keys
in a dictionary (as stored internally in BSArrayFile object)
and simply counting from 1 to total number of microphone channels.
This must be cleaned up later to only use dictionary keys, which
is more general.

Scott Livingston  <slivingston@caltech.edu>
Feb 2011.
"""

import sys
import types
from optparse import OptionParser # Deprecated since Python v2.7, but for folks using 2.5 or 2.6...

import numpy as np
import scipy.special as sp_special
import matplotlib.pyplot as plt

import batstack

# Convenience renaming:
eps = np.finfo(np.float).eps

def piston( f, # frequency
            a_h, a_v,
            theta, phi,
            c=343 ): # speed of sound, in m/s.
    """Rigid elliptical piston in an infinite baffle,

at frequency f Hz,
with horizontal radius a_h (in meters) and vertical radius a_v.

following description in the book by Beranek, Leo L. (1954). Acoustics.
(yes, there is a more recent edition, but I don't have a copy...)

Theta and phi, which are azimuth and elevation, resp., have units of
radians.  P is sound pressure in units of N/m^2 (? this should be
verified). If theta and phi are scalars, or one is a vector, then
behavior is as you would expect: you get a scalar or vector back.

If both theta and phi are vectors, then P is a matrix where where
columns correspond to values of theta, and rows correspond to values
of phi.

NOTES: - It is possible I have made a mistake in the below
         computations. The returned values from besselj are complex
         with, in some places, small but nonzero imaginary
         components.  I address this by taking absolute value of P
         (i.e. complex magnitude); this matches intuition but awaits
         confirmation till I learn more acoustics theory
"""
    k = 2*np.pi*f/c # wave number
    
    if type(theta) is types.IntType or type(theta) is types.FloatType or type(theta) is np.float64:
        theta = np.array([theta], dtype=np.float64)
    else:
        theta = np.array(theta, dtype=np.float64)
    if type(phi) is types.IntType or type(phi) is types.FloatType or type(phi) is np.float64:
        phi = np.array([phi], dtype=np.float64)
    else:
        phi = np.array(phi, dtype=np.float64)
    h_term = k*a_h*np.sin(theta)
    v_term = k*a_v*np.sin(phi)

    h_factor = .5*np.ones(shape=h_term.shape)
    for k in range(len(h_factor)):
        if np.abs(h_term[k]) > 4*np.finfo(np.float64).eps:
            h_factor[k] = sp_special.jn(1, h_term[k])/h_term[k]
    
    v_factor = .5*np.ones(shape=v_term.shape)
    for k in range(len(v_factor)):
        if np.abs(v_term[k]) > 4*np.finfo(np.float64).eps:
            v_factor[k] = sp_special.jn(1, v_term[k])/v_term[k]
    
    if v_factor.shape[0] > 1 and h_factor.shape[0] > 1:
        return 4*np.outer(np.abs(v_factor), np.abs(h_factor)) # make P from outer product.
    else:
        return 4*np.abs(v_factor*h_factor)
    
def test_piston():
    """use case for piston function.
    
...can be used by simply calling from main program entry-point.
test_piston takes frequency from argv list.
"""
    theta = np.linspace(-np.pi/2, np.pi/2, 1000)
    #phi = np.linspace(-np.pi/2, np.pi/2, 30)
    try:
        if len(sys.argv) < 2:
            raise ValueError # a little sloppy to do it this way
        freq = float(sys.argv[1])
    except ValueError:
        print "Usage: %s f" % sys.argv[0]
        exit(1)
    P = piston(freq, .0163, .0163, theta, 0)
    print P.shape
    plt.semilogy(theta, P)
    plt.grid()
    plt.xlabel("angle in radians")
    plt.title(str(freq/1000)+" kHz")
    plt.show()
    
def get_dir(src_pos, mike_pos):
    """Determine r, theta, phi values from source to microphones.

src_pos should follow format as described elsewhere,
i.e. an array of x,y,z,t,p, where
x,y,z are rectangular coordinates and
t,p are spherical-like coordinates (think ``theta'' and
``phi'' for azimuth and elevation with respect to the
x-axis; e.g., t,p = 0,0 indicates aimed parallel to
positive x-axis.

Result is returned as a N x 3 matrix, where N is the number
of microphones (i.e. number of rows in given mike_pos matrix).
"""
    if len(mike_pos.shape) > 1:
        num_mics = mike_pos.shape[0]
        dir_mat = np.zeros(shape=(num_mics, 3))
        for k in range(num_mics):
            trans_vect = np.array([mike_pos[k][j]-src_pos[j] for j in range(3)])
            dir_mat[k][0] = np.sqrt(np.sum([u**2 for u in trans_vect])) # Radius
            dir_mat[k][1] = np.arctan2(trans_vect[1], trans_vect[0])
            dir_mat[k][2] = np.arctan2(trans_vect[2], np.sqrt(trans_vect[0]**2 + trans_vect[1]**2))
    else: # Handle special case of single microphone position
        num_mics = 1
        trans_vect = np.array([mike_pos[j]-src_pos[j] for j in range(3)])
        dir_mat = np.array([0., 0, 0])
        dir_mat[0] = np.sqrt(np.sum([u**2 for u in trans_vect])) # Radius
        dir_mat[1] = np.arctan2(trans_vect[1], trans_vect[0])
        dir_mat[2] = np.arctan2(trans_vect[2], np.sqrt(trans_vect[0]**2 + trans_vect[1]**2))
    return dir_mat

if __name__ == "__main__":
    parser = OptionParser()
    parser.add_option("-f", "--wamike", dest="pos_filename", default=None,
                      help="wamike.txt position file; cf. BatStack ref manual")
    parser.add_option("-p", "--pose", dest="src_pose", default="0,0,0,0,0",
                      help="source position; with respect to the x-axis, and of the form x,y,z,t,p")
    parser.add_option("-t", dest="duration", type="float", default=.1,
                      help="duration of simulated recording.")
    parser.add_option("-w", dest="wnoise", type="float", nargs=2, default=(512, 32),
                      help="mean and variance (in bits) of white background noise.")
    parser.add_option("-c", dest="src_freq", type="float", default=35.,
                      help="piston source frequency (in kHz).")
    parser.add_option("-b", "--bitwidth", dest="sample_width", metavar="BITWIDTH", type="int", default=10,
                      help="sample width of A/D converter; default is 10 bits.")
    parser.add_option("-n", "--nonoise", action="store_true", dest="no_noise", default=False)
    
    (options, args) = parser.parse_args()
    if options.pos_filename is None:
        print "A microphone position file must be provided.\n(See -h for usage note.)"
        exit(1)
        
    if options.sample_width < 0:
        print "Error: sample width must be positive (given %d)." % options.sample_width
        exit(1)
    max_val = 2**(options.sample_width)-1
        
    mike_pos = np.loadtxt(options.pos_filename)
    if (len(mike_pos.shape) == 1 and mike_pos.shape[0] != 3) \
        or mike_pos.shape[1] != 3: # check that mike position file is reasonable
        print "Error: given file appears malformed: %s" % options.pos_filename
        exit(1)
        
    try:
        src_pos = np.array([float(k) for k in options.src_pose.split(",")])
    except ValueError:
        print "Source position invalid; it should be comma-separated real numbers."
        print """E.g., with an x,y,z position of (2, 3.4, -1) and directed
.3 radians CCW on the z-axis and -1.1 radians CCW on the y-axis,
you would enter 2,3.4,-1,.3,-1.1
"""
        exit(1)
        
    sim_bsaf = batstack.BSArrayFile()
    if len(mike_pos.shape) == 1:
        sim_bsaf.num_mics = 1 # Special case of only one microphone
    else:
        sim_bsaf.num_mics = mike_pos.shape[0]
    sim_bsaf.trial_number = 1
    sim_bsaf.notes = "Simulated data!"
    num_samples = np.ceil(options.duration/sim_bsaf.sample_period)
    if not options.no_noise:
        for k in range(sim_bsaf.num_mics):
            #sim_bsaf.data[k+1] = np.random.random_integers(low=0, high=1023, size=1000)
            sim_bsaf.data[k+1] = np.mod(np.ceil(np.abs(np.random.randn(num_samples)
                                                       *options.wnoise[1]+options.wnoise[0])), max_val+1)
            # Note that we wrap white noise outside valid range back into the signal!
            # This procedure is biased toward lower values; explicitly,
            # an absolute value operation and modulo are applied.
            # The abs is natural, but mod causes large signals to appear again near zero.
            # This is in significant contrast to clipping.
    else: # Noiseless recording:
        for k in range(sim_bsaf.num_mics):
            sim_bsaf.data[k+1] = (max_val+1)/2.*np.ones(num_samples)
    
    src_start_ind = int(num_samples/2)
    src_duration = .01 # 10 ms 
    t = np.arange(0, src_duration, sim_bsaf.sample_period)
    x = (max_val+1)/4.*np.sin(2*np.pi*t*options.src_freq*1e3)
    
    dir_mat = get_dir(src_pos, mike_pos)
    P = dict()
    max_P = -1
    for k in sim_bsaf.data.keys():
        P[k] = piston(options.src_freq*1e3, .016, .016,
                      dir_mat[k-1][1], # Theta
                      dir_mat[k-1][2]) # Phi
        if max_P < P[k]:
            max_P = P[k]
    if max_P <= eps:
        print "Warning: max scaling factor is less than machine epsilon."
    for k in P.keys():
        P[k] /= max_P # Normalize
    
    for k in sim_bsaf.data.keys():
        chan_mean = np.mean(sim_bsaf.data[k])
        sim_bsaf.data[k] -= chan_mean
        sim_bsaf.data[k][src_start_ind:(src_start_ind+len(x))] += x*P[k]
        #for x_ind in range(len(x)):
        #    sim_bsaf.data[k+1][src_start_ind+x_ind] += x[x_ind]
        sim_bsaf.data[k] += chan_mean
    
    # Limit signal range
    for k in sim_bsaf.data.keys():
        sim_bsaf.data[k].clip(0, max_val, out=sim_bsaf.data[k])
    
    if sim_bsaf.writefile("test.bin", prevent_overwrite=False) == False:
        print "Error while saving simulation results."
