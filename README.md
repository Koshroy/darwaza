# darwaza

Darwaza is a graphical Gemini browser written in Tcl/Tk. The Gemini protocol gives clients a lot of leeway when rendering the text/gemini display format than what HTML standards allow and other people expect when writing HTML and CSS. Darwaza aims to be a fully dynamic graphical browser, relying heavily on Tk's highly dynamic nature to allow the user to have _full control_ of the rendering pipeline. By allowing users to hook into the render loop of Darwaza, the hope is that users can have full control of how they want to browse Gemini content.
