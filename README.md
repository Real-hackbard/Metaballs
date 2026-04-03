# Metaballs

</br>

![Compiler](https://github.com/user-attachments/assets/a916143d-3f1b-4e1f-b1e0-1067ef9e0401) ![10 Seattle](https://github.com/user-attachments/assets/c70b7f21-688a-4239-87c9-9a03a8ff25ab) ![10 1 Berlin](https://github.com/user-attachments/assets/bdcd48fc-9f09-4830-b82e-d38c20492362) ![10 2 Tokyo](https://github.com/user-attachments/assets/5bdb9f86-7f44-4f7e-aed2-dd08de170bd5) ![10 3 Rio](https://github.com/user-attachments/assets/e7d09817-54b6-4d71-a373-22ee179cd49c)  ![10 4 Sydney](https://github.com/user-attachments/assets/e75342ca-1e24-4a7e-8fe3-ce22f307d881) ![11 Alexandria](https://github.com/user-attachments/assets/64f150d0-286a-4edd-acab-9f77f92d68ad) ![12 Athens](https://github.com/user-attachments/assets/59700807-6abf-4e6d-9439-5dc70fc0ceca)  
![Components](https://github.com/user-attachments/assets/d6a7a7a4-f10e-4df1-9c4f-b4a1a8db7f0e) ![None](https://github.com/user-attachments/assets/30ebe930-c928-4aaf-a8e1-5f68ec1ff349)  
![Description](https://github.com/user-attachments/assets/dbf330e0-633c-4b31-a0ef-b1edb9ed5aa7) ![Metaballs](https://github.com/user-attachments/assets/3cc87c57-1329-4097-abea-a5b6377d158e)  
![Last Update](https://github.com/user-attachments/assets/e1d05f21-2a01-4ecf-94f3-b7bdff4d44dd) ![042026](https://github.com/user-attachments/assets/2446b1e1-a732-4080-97bc-11906d6ff389)  
![License](https://github.com/user-attachments/assets/ff71a38b-8813-4a79-8774-09a2f3893b48) ![Freeware](https://github.com/user-attachments/assets/1fea2bbf-b296-4152-badd-e1cdae115c43)  

</br>

In [computer graphics](https://en.wikipedia.org/wiki/Computer_graphics), metaballs, also known as blobby objects, are organic-looking n-dimensional [isosurfaces](https://en.wikipedia.org/wiki/Isosurface), characterised by their ability to meld together when in close proximity to create single, contiguous objects.

In [solid modelling](https://en.wikipedia.org/wiki/Solid_modeling), [polygon meshes](https://en.wikipedia.org/wiki/Polygon_mesh) are commonly used. In certain instances, however, metaballs are superior. A metaball's "blobby" appearance makes them versatile tools, often used to model organic objects and also to create base meshes for [sculpting](https://en.wikipedia.org/wiki/Digital_sculpting).

The technique for [rendering](https://en.wikipedia.org/wiki/Rendering_(computer_graphics)) metaballs was invented by Jim Blinn in the early 1980s to model atom interactions for Carl Sagan's 1980 TV series Cosmos. It is also referred to colloquially as the "jelly effect" in the [motion](https://en.wikipedia.org/wiki/Motion_graphic_design) and [UX design](https://en.wikipedia.org/wiki/User_experience_design) community, commonly appearing in UI elements such as navigations and buttons. Metaball behavior corresponds to [mitosis](https://en.wikipedia.org/wiki/Mitosis) in cell biology, where chromosomes generate identical copies of themselves through cell division.

# [Blender](https://www.blender.org/) Example:

</br>

![blender-metaballs-1](https://github.com/user-attachments/assets/29e0e1be-351b-4ccc-abcd-136b4dab01ee)

</br>

# Definition:
Each metaball is defined as a function in n dimensions (e.g., for three dimensions, ```f(x,y,z)``` three-dimensional metaballs tend to be most common, with two-dimensional implementations popular as well). A thresholding value is also chosen, to define a solid volume. Then,

### &Sigma; metaball (x,y,z) > thresold

that is, all points larger than the threshold are inside the metaball.



















