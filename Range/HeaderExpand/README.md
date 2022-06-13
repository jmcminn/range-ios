#  Header expanding

## Overview

This folder handles the header expanding/collapsing for views that have one or more headers on top
and a scroll view below. 

Using the `HeaderExpander` it's possible to adjust the header heights based on the user interaction
with the content in the scroll view.

The layout of headers and scroll view is up to the consumer of this folder but the header expander
will calculate the appropriate new header heights to be applied by the consumer.

The asumption is that when header heights update the scroll view position needs to be adapted (so 
it's always right below the headers). 

The `HeaderExpander` is an entry point for the folder and it's documentation describes in more 
detail how the expanding works.

The `HeaderExpanding` file contains some enums used by the expander.

The `HeaderExpanderCalculator` file contains logic for calculating headers states based on the
requested height and is independent of the scroll view gesture handling logic.

