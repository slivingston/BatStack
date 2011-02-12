#!/usr/bin/env python
"""
Simulate microphone array measurement; models BatStack Array. 

Scott Livingston  <slivingston@caltech.edu>
Feb 2011.
"""

import types
from optparse import OptionParser

import numpy as np
import scipy.special as sp_special
import matplotlib.pyplot as plt

def piston( f, # frequency
            a_h, a_v,
            theta, phi,
            c=343 ): # speed of sound, in m/s.
    """Rigid elliptical piston in an infinite baffle,
    
(N.B., this documentation was copied verbatim from the Octave code whence this
was ported, on 11 Feb 2011.)

at frequency f Hz,
with horizontal radius a_h (in meters) and vertical radius a_v.

following description in the book by Beranek, Leo L. (1954). Acoustics.
(yes, there is a more recent edition, but I % don't have a copy...)

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

if __name__ == "__main__":
    # parser = OptionParser()
    # parser.add_option("")
    theta = np.linspace(-np.pi/2,np.pi/2.,100)
    P = piston(30e3, .01, .01, 0, theta)
    #print P.shape
    plt.polar(theta+np.pi/2, P)
    plt.show()
