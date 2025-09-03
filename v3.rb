require 'gtk3'
require 'rsvg2'
require 'cairo'
require 'nokogiri'

class CompleteSVGAnimatorWithControls
  def initialize(svg_file = nil)
    @time = 0
    @animation_speed = 0.05
    @is_playing = false
    @svg_file = svg_file
    @svg_content = File.read(svg_file) if svg_file && File.exist?(svg_file)

    setup_gui
  end

  def setup_gui
    # Fenêtre principale
    @window = Gtk::Window.new("Animation SVG Ruby avec Redimensionnement")
    @window.set_default_size(1000, 600)
    @window.signal_connect('destroy') { Gtk.main_quit }

    # Conteneur horizontal principal
    main_box = Gtk::Box.new(:horizontal, 5)
    @window.add(main_box)

    # Zone de dessin avec redimensionnement
    @drawing_area = Gtk::DrawingArea.new
    @drawing_area.set_hexpand(true)
    @drawing_area.set_vexpand(true)

    # Cadre pour la zone de dessin
    drawing_frame = Gtk::Frame.new
    drawing_frame.set_hexpand(true)
    drawing_frame.set_vexpand(true)
    drawing_frame.add(@drawing_area)
    main_box.pack_start(drawing_frame, :expand => true, :fill => true, :padding => 5)

    # Panneau de contrôle vertical
    control_panel = Gtk::Box.new(:vertical, 10)
    control_panel.set_size_request(180, -1)
    control_panel.margin = 10

    # Titre du panneau
    title_label = Gtk::Label.new
    title_label.markup = "<b>Contrôles d'Animation</b>"
    title_label.margin_bottom = 20
    control_panel.pack_start(title_label, :expand => false, :fill => false, :padding => 5)

    # Bouton Charger SVG
    @load_button = Gtk::Button.new(:label => "Charger SVG")
    @load_button.signal_connect('clicked') { load_svg_file }
    control_panel.pack_start(@load_button, :expand => false, :fill => true, :padding => 5)

    # Bouton Play/Pause
    @play_button = Gtk::Button.new(:label => "▶ Démarrer")
    @play_button.signal_connect('clicked') { toggle_animation }
    control_panel.pack_start(@play_button, :expand => false, :fill => true, :padding => 5)

    # Contrôle de vitesse
    speed_box = Gtk::Box.new(:vertical, 5)
    speed_label = Gtk::Label.new("Vitesse d'animation:")
    speed_box.pack_start(speed_label, :expand => false, :fill => false, :padding => 2)

    speed_buttons_box = Gtk::Box.new(:horizontal, 5)

    slow_button = Gtk::Button.new(:label => "⏪ Ralentir")
    slow_button.signal_connect('clicked') { change_speed(-0.01) }
    speed_buttons_box.pack_start(slow_button, :expand => true, :fill => true, :padding => 2)

    fast_button = Gtk::Button.new(:label => "⏩ Accélérer")
    fast_button.signal_connect('clicked') { change_speed(0.01) }
    speed_buttons_box.pack_start(fast_button, :expand => true, :fill => true, :padding => 2)

    speed_box.pack_start(speed_buttons_box, :expand => false, :fill => true, :padding => 2)
    control_panel.pack_start(speed_box, :expand => false, :fill => true, :padding => 5)

    # Affichage de la vitesse actuelle
    @speed_label = Gtk::Label.new("Vitesse: #{(@animation_speed * 100).round(1)}%")
    control_panel.pack_start(@speed_label, :expand => false, :fill => false, :padding => 5)

    # Options de redimensionnement
    resize_box = Gtk::Box.new(:vertical, 5)
    resize_label = Gtk::Label.new("Redimensionnement:")
    resize_box.pack_start(resize_label, :expand => false, :fill => false, :padding => 2)

    resize_buttons_box = Gtk::Box.new(:horizontal, 5)

    @fit_button = Gtk::ToggleButton.new(:label => "🔍 Adapter")
    @fit_button.active = true
    @fit_button.signal_connect('toggled') { @drawing_area.queue_draw }
    resize_buttons_box.pack_start(@fit_button, :expand => true, :fill => true, :padding => 2)

    @original_button = Gtk::ToggleButton.new(:label => "1:1 Original")
    @original_button.signal_connect('toggled') {
      if @original_button.active?
        @fit_button.active = false
        @drawing_area.queue_draw
      end
    }
    resize_buttons_box.pack_start(@original_button, :expand => true, :fill => true, :padding => 2)

    resize_box.pack_start(resize_buttons_box, :expand => false, :fill => true, :padding => 2)
    control_panel.pack_start(resize_box, :expand => false, :fill => true, :padding => 5)

    # Bouton Capture d'écran
    @screenshot_button = Gtk::Button.new(:label => "📸 Capturer")
    @screenshot_button.signal_connect('clicked') { take_screenshot }
    control_panel.pack_start(@screenshot_button, :expand => false, :fill => true, :padding => 5)

    # Bouton Réinitialiser
    @reset_button = Gtk::Button.new(:label => "↺ Réinitialiser")
    @reset_button.signal_connect('clicked') { reset_animation }
    control_panel.pack_start(@reset_button, :expand => false, :fill => true, :padding => 5)

    # Statut de l'animation
    @status_label = Gtk::Label.new("Arrêté")
    @status_label.margin_top = 20
    control_panel.pack_start(@status_label, :expand => false, :fill => false, :padding => 5)

    # Info de dimension
    @dimension_label = Gtk::Label.new("")
    control_panel.pack_start(@dimension_label, :expand => false, :fill => false, :padding => 5)

    # Ajouter le panneau de contrôle
    control_frame = Gtk::Frame.new
    control_frame.add(control_panel)
    main_box.pack_start(control_frame, :expand => false, :fill => true, :padding => 5)

    # Configuration du dessin
    @drawing_area.signal_connect('draw') { |widget, cr| draw_animated_svg(cr) }

    # Surveiller le redimensionnement
    @drawing_area.signal_connect('size-allocate') do |widget, allocation|
      @drawing_width = allocation.width
      @drawing_height = allocation.height
      @dimension_label.label = "#{@drawing_width}×#{@drawing_height}px"
    end

    # Timer d'animation
    @animation_id = GLib::Timeout.add(16) do
      if @is_playing
        @time += @animation_speed
        @drawing_area.queue_draw
        @status_label.label = "En cours: #{@time.round(2)}s"
      end
      true
    end

    # Initialisation des dimensions
    @drawing_width = 800
    @drawing_height = 600
  end

  def calculate_svg_transform(svg_width, svg_height)
    return nil if @drawing_width.nil? || @drawing_height.nil?

    if @fit_button.active?
      # Mode "Adapter" - redimensionner pour fitter dans la zone
      scale_x = @drawing_width.to_f / svg_width
      scale_y = @drawing_height.to_f / svg_height
      scale = [scale_x, scale_y].min

      # Centrer
      x_offset = (@drawing_width - (svg_width * scale)) / 2
      y_offset = (@drawing_height - (svg_height * scale)) / 2

      { scale: scale, x: x_offset, y: y_offset }
    else
      # Mode "Original" - centrer sans redimensionner
      x_offset = (@drawing_width - svg_width) / 2
      y_offset = (@drawing_height - svg_height) / 2

      { scale: 1.0, x: x_offset, y: y_offset }
    end
  end

  def load_svg_file
    dialog = Gtk::FileChooserDialog.new(
      title: "Choisir un fichier SVG",
      parent: @window,
      action: :open,
      buttons: [
        ["Annuler", :cancel],
        ["Ouvrir", :accept]
      ]
    )

    filter = Gtk::FileFilter.new
    filter.name = "Fichiers SVG"
    filter.add_pattern("*.svg")
    dialog.add_filter(filter)

    if dialog.run == :accept
      @svg_file = dialog.filename
      begin
        @svg_content = File.read(@svg_file)
        @time = 0
        @drawing_area.queue_draw

        # Récupérer les dimensions du SVG
        doc = Nokogiri::XML(@svg_content)
        svg_elem = doc.at_css('svg')
        if svg_elem
          svg_width = svg_elem['width'].to_i
          svg_height = svg_elem['height'].to_i
          @status_label.label = "SVG: #{svg_width}×#{svg_height}px"
        else
          @status_label.label = "SVG chargé: #{File.basename(@svg_file)}"
        end

      rescue => e
        show_error("Erreur de chargement: #{e.message}")
      end
    end

    dialog.destroy
  end

  def toggle_animation
    @is_playing = !@is_playing
    @play_button.label = @is_playing ? "⏸ Pause" : "▶ Démarrer"
    @status_label.label = @is_playing ? "En cours" : "En pause"
  end

  def change_speed(delta)
    @animation_speed = (@animation_speed + delta).clamp(0.01, 0.2)
    @speed_label.label = "Vitesse: #{(@animation_speed * 100).round(1)}%"
  end

  def take_screenshot
    return unless @svg_content

    dialog = Gtk::FileChooserDialog.new(
      title: "Enregistrer la capture",
      parent: @window,
      action: :save,
      buttons: [
        ["Annuler", :cancel],
        ["Enregistrer", :accept]
      ]
    )

    dialog.current_name = "capture_#{Time.now.strftime('%Y%m%d_%H%M%S')}.png"

    if dialog.run == :accept
      filename = dialog.filename

      # Créer une surface Cairo pour le rendu
      surface = Cairo::ImageSurface.new(:argb32, @drawing_width, @drawing_height)
      cr = Cairo::Context.new(surface)

      # Dessiner le SVG animé avec la même transformation
      draw_animated_svg(cr)

      # Sauvegarder en PNG
      surface.write_to_png(filename)

      @status_label.label = "Capture: #{File.basename(filename)}"
    end

    dialog.destroy
  end

  def reset_animation
    @time = 0
    @drawing_area.queue_draw
    @status_label.label = "Réinitialisé"
  end

  def show_error(message)
    dialog = Gtk::MessageDialog.new(
      parent: @window,
      flags: :modal,
      type: :error,
      buttons: :ok,
      message: message
    )
    dialog.run
    dialog.destroy
  end

  def draw_animated_svg(cr)
    return unless @svg_content

    # Fond gris foncé
    cr.set_source_rgb(0.1, 0.1, 0.1)
    cr.paint

    begin
      # Mettre à jour le SVG avec les animations
      doc = Nokogiri::XML(@svg_content)
      update_svg_animations(doc)

      # Créer un fichier temporaire
      temp_file = "/tmp/animated_#{Time.now.to_f}.svg"
      File.write(temp_file, doc.to_xml)

      # Charger le SVG
      handle = Rsvg::Handle.new_from_file(temp_file)

      # Récupérer les dimensions du SVG
      svg_dim = handle.dimensions
      svg_width = svg_dim.width
      svg_height = svg_dim.height

      # Calculer la transformation
      transform = calculate_svg_transform(svg_width, svg_height)

      if transform
        cr.save

        # Appliquer la transformation
        cr.translate(transform[:x], transform[:y])
        cr.scale(transform[:scale], transform[:scale])

        # Dessiner le SVG
        handle.render_cairo(cr)

        cr.restore
      else
        # Dessiner sans transformation
        handle.render_cairo(cr)
      end

      File.delete(temp_file) if File.exist?(temp_file)

    rescue => e
      cr.set_source_rgb(1, 0, 0)
      cr.move_to(50, 50)
      cr.show_text("Erreur: #{e.message}")
    end
  end

  def update_svg_animations(doc)
    return unless doc

    # 1. Cercle animé
    if (cercle = doc.at_css('#cercle-anime'))
      x = 100 + Math.sin(@time) * 150
      y = 100 + Math.cos(@time) * 100
      cercle['cx'] = x.round(2).to_s
      cercle['cy'] = y.round(2).to_s
    end

    # 2. Rectangle tournant
    if (rect = doc.at_css('#rectangle-tournant'))
      center_x = 200 + 40
      center_y = 150 + 40
      angle = @time * 2
      rect['transform'] = "rotate(#{angle * (180/Math::PI)} #{center_x} #{center_y})"
    end

    # 3. Étoile morphing
    if (etoile = doc.at_css('#etoile-morph'))
      points = []
      10.times do |i|
        angle = i * Math::PI / 5
        radius = 40 + Math.sin(@time + i * 0.5) * 15
        x = 350 + radius * Math.cos(angle)
        y = 100 + radius * Math.sin(angle)
        points << "#{x.round(2)},#{y.round(2)}"
      end
      etoile['points'] = points.join(' ')
    end

    # 4. Groupe animé
    if (groupe = doc.at_css('#groupe-anime'))
      x = 500 + Math.sin(@time * 1.2) * 100
      y = 200 + Math.cos(@time * 0.8) * 80
      groupe['transform'] = "translate(#{x.round(2)}, #{y.round(2)})"
    end

    # 5. Ligne morphing
    if (ligne = doc.at_css('#ligne-morph'))
      control_x = 150 + Math.sin(@time) * 50
      control_y = 325 + Math.cos(@time) * 25
      end_x = 200 + Math.sin(@time * 1.5) * 30
      end_y = 350 + Math.cos(@time * 1.2) * 20
      ligne['d'] = "M100 300 Q#{control_x.round(2)} #{control_y.round(2)} #{end_x.round(2)} #{end_y.round(2)}"
    end

    # 6. Texte animé
    if (texte = doc.at_css('#texte-anime'))
      x = 400 + Math.sin(@time * 0.7) * 50
      texte['x'] = x.round(2).to_s
    end

    # 7. Vaisseau spatial
    if (vaisseau = doc.at_css('#vaisseau-spatial'))
      x = 150 + @time * 20
      y = 450 + Math.sin(@time * 0.5) * 40
      angle = Math.atan2(Math.cos(@time * 0.5), 1) * 0.5
      vaisseau['transform'] = "translate(#{x % 800}, #{y}) rotate(#{angle * (180/Math::PI)})"
    end

    # 8. Particules
    ['particule1', 'particule2', 'particule3'].each_with_index do |id, index|
      if (particule = doc.at_css("##{id}"))
        phase = index * Math::PI / 3
        x = 600 + index * 20 + Math.sin(@time + phase) * 30
        y = 100 + index * 20 + Math.cos(@time + phase) * 40
        particule['cx'] = x.round(2).to_s
        particule['cy'] = y.round(2).to_s
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
  animator = CompleteSVGAnimatorWithControls.new('test_animation.svg')
  animator.run
rescue => e
  puts "Erreur: #{e.message}"
  puts "Assurez-vous d'avoir le fichier test_animation.svg dans le même dossier"
end
