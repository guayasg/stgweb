class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  helper_method :pintar_menu
  def pintar_menu(nivel)
    #la función de base de datos que llamemos debe de indicarnos el nivel, quien es el padre (id, nombre del padre)
    #Menu=Menu_frame
=begin    
    Menu+=link_toUP(nivel) + link_toEmpresa +  
    '<header class="navbar navbar-inverse navbar-fixed-top bs-docs-nav" role="banner">
    <div class="Menu">
      <div class="navbar-header">
        <button class="navbar-toggle" type="button" data-toggle="collapse" data-target=".bs-navbar-collapse">
          <span class="sr-only">Toggle navigation</span>
          <span class= "icon-bar"></span>
          <span class="icon-bar"></span>
          <span class="icon-bar"></span>
        </button>
        {#}
        <a href="./" class="navbar-brand">Bootstra stgweb p 3 Menu Generator</a>
      </div>
      <nav class="collapse navbar-collapse bs-navbar-collapse" role="navigation">
        <ul class="nav navbar-nav">
        <li>
          <a href="#">Getting started</a>
        </li>
        <li class="dropdown">
          <a href="#" class="dropdown-toggle" data-toggle="dropdown">Dropdown <b class="caret"></b></a>
          <ul class="dropdown-menu">
            <li><a href="#">Action</a></li>
            <li><a href="#">Another action</a></li>
            <li><a href="#">Something else here</a></li>
            <li><a href="#">Separated link</a></li>
            <li><a href="#">One more separated link</a></li>
          </ul>
        </li>
        <li>
          <a href="#">Components</a>
        </li>
        <li>
          <a href="#">JavaScript</a>
        </li>
        <li class="active">
          <a href="#">Customize</a>
        </li>
      </ul>
    </nav>
  </div>
</header>'
=end    
  end
  
end
