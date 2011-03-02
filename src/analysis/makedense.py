#!/usr/bin/env python
"""
Generate random new positions within region of given microphone array.

This is, at least, useful for up-sampling the sonar beam in Array simulations,
while including real, original experimental microphone positions (with their
same labeling as well; i.e., up-sampled positions are appended to given list).


Scott Livingston  <slivingston@caltech.edu>
1 Mar 2011.
"""

import numpy as np
import sys


def box_fill(mike_pos, num_new_mics):
    """
Generate random new mike positions uniformly in rectangle spanned by given
positions.  Note this approach is a bit stupid because it depends on coordinate
frame (rather than a tight-fitting rectangle).

Returns result as augmented matrix (with originals in their original locations).
"""
    if len(mike_pos.shape) == 1: # Only one mic?
        num_given_mics = 1
    else:
        num_given_mics = mike_pos.shape[0]

    min_coords = mike_pos.min(axis=0)
    max_coords = mike_pos.max(axis=0)
    scale_mat = np.outer(np.ones(num_new_mics), max_coords-min_coords)
    
    # Generate random new mike positions uniformly in rectangle
    # spanned by given positions.
    mike_pos = np.resize(mike_pos, (num_given_mics+num_new_mics, 3))
    mike_pos[num_given_mics:] = np.random.random(size=(num_new_mics, 3))*scale_mat \
                                + np.outer(np.ones(num_new_mics), min_coords)
    return mike_pos

def web_sample(mike_pos, num_new_mics):
    """Randomly add microphones on complete graph formed by given array.
    
That is, each additional microphone position is chosen by:

1. Find a random pair of (distinct) microphones in given array.
2. Select a random position on the edge connecting this pair.
3. Place the new microphone there (in x,y,z coordinates, of course).
4. Iterate...

Returns result as augmented matrix (with originals in their original locations).
If error, returns empty list.
"""
    if len(mike_pos.shape) == 1: # Only one mic?
        num_given_mics = 1
        return [] # Error! this method requires at least two prior microphones.
    else:
        num_given_mics = mike_pos.shape[0]
    
    mike_list = []
    for k in range(num_new_mics):
        mic1_index = np.random.randint(low=0, high=num_given_mics)
        while True: # Lazy loop; implementation could be more efficient here!
            mic2_index = np.random.randint(low=0, high=num_given_mics)
            if mic2_index != mic1_index:
                break
        mike_list.append((mike_pos[mic2_index]-mike_pos[mic1_index])*np.random.random() + mike_pos[mic1_index])

    mike_pos = np.resize(mike_pos, (num_given_mics+num_new_mics, 3))
    mike_pos[num_given_mics:] = np.array(mike_list)
    return mike_pos

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print "Usage: %s wamike-orig N [wamike-new]" % sys.argv[0]
        exit(1)
        
    if len(sys.argv) >= 4:
        out_filename = sys.argv[3]
    else:
        out_filename = "NEW-" + sys.argv[1]
    
    try:
        num_new_mics = int(sys.argv[2])
    except ValueError:
        print "Error: invalid number of new microphones."
        exit(-1)
    if num_new_mics < 1:
        print "Error: must add at least one mic (i.e. N > 0)."
        exit(-1)
    
    mike_pos = np.loadtxt(sys.argv[1])
    if (len(mike_pos.shape) == 1 and mike_pos.shape[0] != 3) \
        or mike_pos.shape[1] != 3: # check that mike position file is reasonable
        print "Error: given file appears malformed: %s" % sys.argv[1]
        exit(1)
        
    mike_pos = web_sample(mike_pos, num_new_mics)
    
    np.savetxt(out_filename, mike_pos)
