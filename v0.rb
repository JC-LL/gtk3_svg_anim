require 'gtk3'
require 'rsvg2'
require 'cairo'
require 'nokogiri'

class CompleteSVGAnimator
  def initialize(svg_file)
    @window = Gtk::Window.new("Animation SVG Ruby Complète")
    @window.set_default_size(800, 600)
    @window.signal_connect('destroy') { Gtk.main_quit }

    @drawing_area = Gtk::DrawingArea.new
    @window.add(@drawing_area)

    # Charger le SVG original
    @svg_content = File.read(svg_file)
    @doc = Nokogiri::XML(@svg_content)
    @time = 0

    @drawing_area.signal_connect('draw') { |widget, cr| draw_animated_svg(cr) }

    # Animation à 60 FPS
    GLib::Timeout.add(16) do
      @time += 0.05
      @drawing_area.queue_draw
      true
    end
  end

  def draw_animated_svg(cr)
    # Mettre à jour le SVG avec les animations
    update_svg_animations

    # Créer un fichier temporaire avec le SVG animé
    temp_file = "/tmp/animated_#{Time.now.to_f}.svg"
    File.write(temp_file, @doc.to_xml)

    # Charger et dessiner le SVG animé
    handle = Rsvg::Handle.new_from_file(temp_file)

    cr.set_source_rgb(0, 0, 0)
    cr.paint

    handle.render_cairo(cr)

    # Nettoyer
    File.delete(temp_file) if File.exist?(temp_file)
  end

  def update_svg_animations
    # Réinitialiser le document à chaque frame
    @doc = Nokogiri::XML(@svg_content)

    # 1. Cercle animé - Mouvement circulaire
    cercle = @doc.at_css('#cercle-anime')
    if cercle
      x = 100 + Math.sin(@time) * 150
      y = 100 + Math.cos(@time) * 100
      cercle['cx'] = x.round(2).to_s
      cercle['cy'] = y.round(2).to_s

      # Changement de couleur
      red = (Math.sin(@time) + 1) / 2
      blue = (Math.cos(@time * 0.7) + 1) / 2
      cercle['fill'] = "rgb(#{(red * 255).to_i}, #{(blue * 255).to_i}, 100)"
    end

    # 2. Rectangle tournant - Rotation autour du centre
    rect = @doc.at_css('#rectangle-tournant')
    if rect
      center_x = 200 + 40  # x + width/2
      center_y = 150 + 40  # y + height/2
      angle = @time * 2
      rect['transform'] = "rotate(#{angle * (180/Math::PI)} #{center_x} #{center_y})"

      # Changement de taille
      scale = 0.8 + Math.sin(@time * 0.5) * 0.2
      rect['width'] = (80 * scale).to_i.to_s
      rect['height'] = (80 * scale).to_i.to_s
    end

    # 3. Étoile morphing - Transformation de forme
    etoile = @doc.at_css('#etoile-morph')
    if etoile
      # Animation des points de l'étoile
      points = []
      10.times do |i|
        angle = i * Math::PI / 5
        radius = 40 + Math.sin(@time + i * 0.5) * 15
        x = 350 + radius * Math.cos(angle)
        y = 100 + radius * Math.sin(angle)
        points << "#{x.round(2)},#{y.round(2)}"
      end
      etoile['points'] = points.join(' ')

      # Couleur pulsante
      intensity = (Math.sin(@time) + 1) * 0.5
      etoile['fill'] = "rgb(#{(intensity * 255).to_i}, #{(intensity * 200).to_i}, 0)"
    end

    # 4. Groupe animé - Mouvement complexe
    groupe = @doc.at_css('#groupe-anime')
    if groupe
      x = 500 + Math.sin(@time * 1.2) * 100
      y = 200 + Math.cos(@time * 0.8) * 80
      scale = 1 + Math.sin(@time * 0.3) * 0.3
      groupe['transform'] = "translate(#{x.round(2)}, #{y.round(2)}) scale(#{scale.round(2)})"
    end

    # 5. Ligne morphing - Changement de forme
    ligne = @doc.at_css('#ligne-morph')
    if ligne
      # Courbe de Bézier animée
      control_x = 150 + Math.sin(@time) * 50
      control_y = 325 + Math.cos(@time) * 25
      end_x = 200 + Math.sin(@time * 1.5) * 30
      end_y = 350 + Math.cos(@time * 1.2) * 20

      ligne['d'] = "M100 300 Q#{control_x.round(2)} #{control_y.round(2)} #{end_x.round(2)} #{end_y.round(2)}"

      # Épaisseur variable
      ligne['stroke-width'] = (3 + Math.sin(@time) * 2).to_i.to_s
    end

    # 6. Texte animé - Effets multiples
    texte = @doc.at_css('#texte-anime')
    if texte
      # Mouvement
      x = 400 + Math.sin(@time * 0.7) * 50
      texte['x'] = x.round(2).to_s

      # Taille variable
      size = 20 + Math.sin(@time) * 8
      texte['font-size'] = size.round(2).to_s

      # Couleur arc-en-ciel
      hue = (@time * 50) % 360
      texte['fill'] = "hsl(#{hue.round(2)}, 100%, 60%)"
    end

    # 7. Vaisseau spatial - Mouvement de vaisseau
    vaisseau = @doc.at_css('#vaisseau-spatial')
    if vaisseau
      # Trajectoire sinusoïdale
      x = 150 + @time * 20
      y = 450 + Math.sin(@time * 0.5) * 40

      # Orientation selon la direction
      angle = Math.atan2(Math.cos(@time * 0.5), 1) * 0.5

      vaisseau['transform'] = "translate(#{x % 800}, #{y}) rotate(#{angle * (180/Math::PI)})"
    end

    # 8. Particules - Effet de dispersion
    ['particule1', 'particule2', 'particule3'].each_with_index do |id, index|
      particule = @doc.at_css("##{id}")
      next unless particule

      # Mouvement circulaire avec phase différente
      phase = index * Math::PI / 3
      x = 600 + index * 20 + Math.sin(@time + phase) * 30
      y = 100 + index * 20 + Math.cos(@time + phase) * 40

      particule['cx'] = x.round(2).to_s
      particule['cy'] = y.round(2).to_s

      # Taille variable
      radius = 5 + index + Math.sin(@time * 2 + phase) * 3
      particule['r'] = radius.round(2).to_s
    end

    # 9. Forme complexe - Courbe animée
    forme = @doc.at_css('#forme-complexe')
    if forme
      # Animation des points de contrôle
      control1_x = 750 + Math.sin(@time) * 30
      control1_y = 250 + Math.cos(@time) * 20
      control2_x = 850 + Math.sin(@time * 1.2) * 40
      control2_y = 300 + Math.cos(@time * 0.8) * 30

      forme['d'] = "M700 300 Q#{control1_x.round(2)} #{control1_y.round(2)} 800 300 T#{control2_x.round(2)} #{control2_y.round(2)}"

      # Couleur changeante
      forme['stroke'] = "hsl(#{(@time * 30) % 360}, 80%, 60%)"
    end

    # 10. Fond - Dégradé animé
    fond = @doc.at_css('#fond')
    if fond
      # Modifier le dégradé (plus complexe à manipuler, on change juste la couleur de base)
      gradient = @doc.at_css('linearGradient#fond-gradient stop:first-child')
      if gradient
        hue = (@time * 10) % 360
        gradient['stop-color'] = "hsl(#{hue}, 70%, 40%)"
      end
    end
  end

  def run
    @window.show_all
    Gtk.main
  end
end

# Utilisation
begin
  animator = CompleteSVGAnimator.new('test_animation.svg')
  animator.run
rescue => e
  puts "Erreur: #{e.message}"
  puts "Assurez-vous d'avoir installé les gems: gem install gtk3 rsvg2 nokogiri"
end
