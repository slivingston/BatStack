#!/usr/bin/env python
"""
Simulate microphone array measurement; models BatStack Array. 

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
    
    if type(theta) is types.IntType or type(theta) is types.FloatType:
        theta = np.array([theta], dtype=np.float64)
    else:
        theta = np.array(theta, dtype=np.float64)
    if type(phi) is types.IntType or type(phi) is types.FloatType:
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

if __name__ == "__main__":
    parser = OptionParser()
    parser.add_option("-f", "--wamike", dest="pos_filename", default=None,
                      help="wamike.txt position file; cf. BatStack ref manual")
    parser.add_option("-p", "--pose", dest="src_pose", default="0,0,0,0,0",
                      help="source position; with respect to the x-axis, and of the form x,y,z,t,p")
    parser.add_option("-t", dest="duration", type="float", default=.01,
                      help="duration of simulated recording.")
    parser.add_option("-w", dest="wnoise", type="float", nargs=2, default=(512, 32),
                      help="mean and variance (in bits) of white background noise.")
    
    (options, args) = parser.parse_args()
    if options.pos_filename is None:
        print "A microphone position file must be provided.\n(See -h for usage note.)"
        exit(1)
        
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
    num_samples = np.ceil(options.duration/sim_bsaf.sample_period)
    for k in range(sim_bsaf.num_mics):
        #sim_bsaf.data[k+1] = np.random.random_integers(low=0, high=1023, size=1000)
        sim_bsaf.data[k+1] = np.mod(np.ceil(np.abs(np.random.randn(num_samples)
                                                   *options.wnoise[1]+options.wnoise[0])), 1024)
    if sim_bsaf.writefile("test.bin", prevent_overwrite=False) == False:
        print "Error while saving simulation results."
