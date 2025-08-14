/**
     * 🎯 NIMBA HEADER - OPTIMISÉ POUR LA PERFORMANCE ET L'ACCESSIBILITÉ
     * 🔥 CORRECTION DU BUG: Mega-menu qui bloque les clics après fermeture
     */
    class NimbaHeader {
      constructor() {
        // Éléments DOM avec vérification d'existence
        this.header = document.querySelector('.header');
        this.burger = document.getElementById('burgerMenu');
        this.megaMenu = document.getElementById('megaMenu');
        
        // État du menu
        this.isMenuOpen = false;
        this.isScrolling = false;
        this.scrollTimer = null;
        this.resizeTimer = null;
        
        // Mémorisation de la position de scroll
        this.lastScrollY = 0;
        this.scrollThreshold = window.innerWidth < 768 ? 60 : 100;
        
        // Binding des méthodes
        this.handleScroll = this.throttle(this.handleScroll.bind(this), 16);
        this.handleResize = this.debounce(this.handleResize.bind(this), 250);
        
        // Vérification des éléments requis
        if (!this.header || !this.burger || !this.megaMenu) {
          console.error('NimbaHeader: Éléments DOM requis manquants');
          return;
        }
        
        this.init();
      }

      /**
       * 🚀 INITIALISATION
       */
      init() {
        try {
          // Gestionnaires d'événements
          this.addEventListeners();
          
          // Configuration initiale
          this.setupInitialState();
          
          // Configuration de l'accessibilité
          this.setupAccessibility();
          
          console.log('NimbaHeader: Initialisé avec succès - Bug du mega-menu corrigé');
        } catch (error) {
          console.error('NimbaHeader: Erreur lors de l\'initialisation:', error);
        }
      }

      /**
       * 📡 AJOUT DES GESTIONNAIRES D'ÉVÉNEMENTS
       */
      addEventListeners() {
        // Burger menu (mobile uniquement)
        this.burger.addEventListener('click', this.handleBurgerClick.bind(this));
        
        // Scroll avec throttling
        window.addEventListener('scroll', this.handleScroll, { passive: true });
        
        // Resize avec debouncing
        window.addEventListener('resize', this.handleResize, { passive: true });
        
        // Sous-menus (mobile uniquement)
        this.setupSubMenus();
        
        // Fermeture externe et clavier
        this.setupExternalClosing();
        
        // Gestion du focus trap dans le menu
        this.setupFocusTrap();
      }

      /**
       * 🎯 GESTION DU BURGER MENU
       */
      handleBurgerClick(e) {
        e.preventDefault();
        e.stopPropagation();
        
        if (window.innerWidth >= 768) return;
        
        this.isMenuOpen ? this.closeMenu() : this.openMenu();
        
        // Retour haptique sur mobile
        if ('vibrate' in navigator && /Android|iPhone|iPad|iPod/i.test(navigator.userAgent)) {
          navigator.vibrate(30);
        }
      }

      /**
       * 📂 OUVERTURE DU MENU
       */
      openMenu() {
        if (this.isMenuOpen) return;
        
        this.isMenuOpen = true;
        this.burger.setAttribute('aria-expanded', 'true');
        this.burger.classList.add('active');
        this.megaMenu.classList.add('show');
        
        // 🔥 FIX: S'assurer que le mega-menu reçoit les événements quand ouvert
        this.megaMenu.style.pointerEvents = 'auto';
        this.megaMenu.style.zIndex = '1002';
        
        // Prévention du scroll du body
        document.body.style.overflow = 'hidden';
        
        // Focus sur le premier élément focusable du menu
        this.focusFirstMenuItem();
        
        // Animation avec requestAnimationFrame pour la performance
        requestAnimationFrame(() => {
          this.megaMenu.style.maxHeight = this.megaMenu.scrollHeight + 'px';
        });
      }

      /**
       * 📂 FERMETURE DU MENU
       */
      closeMenu() {
        if (!this.isMenuOpen) return;
        
        this.isMenuOpen = false;
        this.burger.setAttribute('aria-expanded', 'false');
        this.burger.classList.remove('active');
        this.megaMenu.classList.remove('show');
        
        // 🔥 FIX CRITIQUE: Désactiver complètement le mega-menu quand fermé
        this.megaMenu.style.pointerEvents = 'none';
        this.megaMenu.style.zIndex = '-1';
        
        // Restauration du scroll du body
        document.body.style.overflow = '';
        
        // Fermeture de tous les sous-menus
        this.closeAllSubMenus();
        
        // 🔥 FIX: Forcer le reflow pour s'assurer que les changements sont appliqués
        this.megaMenu.offsetHeight;
        
        // Retour du focus au burger avec délai pour éviter les conflits
        setTimeout(() => {
          if (!this.isMenuOpen) {
            this.burger.focus();
          }
        }, 50);
      }

      /**
       * 🔄 GESTION DU SCROLL AVEC OPTIMISATION
       */
      handleScroll() {
        const currentScrollY = window.scrollY;
        const isMobile = window.innerWidth < 768;
        
        // Éviter les calculs inutiles
        if (Math.abs(currentScrollY - this.lastScrollY) < 2) return;
        
        // Application des effets selon le viewport
        if (isMobile) {
          this.applyMobileScrollEffect(currentScrollY);
        } else {
          this.applyDesktopScrollEffect(currentScrollY);
        }
        
        this.lastScrollY = currentScrollY;
        
        // Fermeture du menu mobile si ouvert pendant le scroll
        if (isMobile && this.isMenuOpen) {
          this.closeMenu();
        }
      }

      /**
       * 📱 EFFET SCROLL MOBILE
       */
      applyMobileScrollEffect(scrollY) {
        const shouldHide = scrollY > this.scrollThreshold;
        
        if (shouldHide !== this.header.classList.contains('scrolled')) {
          this.header.classList.toggle('scrolled', shouldHide);
        }
      }

      /**
       * 🖥️ EFFET SCROLL DESKTOP
       */
      applyDesktopScrollEffect(scrollY) {
        const shouldHide = scrollY > 100;
        
        if (shouldHide !== this.header.classList.contains('scrolled')) {
          this.header.classList.toggle('scrolled', shouldHide);
        }
      }

      /**
       * 🔍 GESTION DU RESIZE
       */
      handleResize() {
        const isMobile = window.innerWidth < 768;
        
        // Mise à jour du seuil de scroll
        this.scrollThreshold = isMobile ? 60 : 100;
        
        // Fermeture du menu mobile si passage en desktop
        if (!isMobile && this.isMenuOpen) {
          this.closeMenu();
        }
        
        // 🔥 FIX: Réinitialisation complète du mega-menu selon le viewport
        if (isMobile) {
          // Mode mobile: comportement dropdown
          if (!this.isMenuOpen) {
            this.megaMenu.style.pointerEvents = 'none';
            this.megaMenu.style.zIndex = '-1';
          }
        } else {
          // Mode desktop: comportement normal
          this.megaMenu.style.pointerEvents = '';
          this.megaMenu.style.zIndex = '';
        }
        
        // Réinitialisation des styles en cas de changement de breakpoint
        this.resetResponsiveStyles();
      }

      /**
       * 📋 CONFIGURATION DES SOUS-MENUS
       */
      setupSubMenus() {
        const buttons = this.megaMenu.querySelectorAll('button[data-submenu]');
        
        buttons.forEach(button => {
          button.addEventListener('click', (e) => {
            if (window.innerWidth >= 768) return; // Desktop = hover uniquement
            
            e.preventDefault();
            e.stopPropagation();
            
            const submenuId = button.getAttribute('data-submenu');
            const submenu = document.getElementById(submenuId);
            
            if (!submenu) return;
            
            const isOpen = submenu.classList.contains('show');
            
            // Fermeture des autres sous-menus
            this.closeAllSubMenus();
            
            // Toggle du sous-menu actuel
            if (!isOpen) {
              this.openSubMenu(button, submenu);
            }
          });
        });
      }

      /**
       * 📂 OUVERTURE D'UN SOUS-MENU
       */
      openSubMenu(button, submenu) {
        button.setAttribute('aria-expanded', 'true');
        submenu.classList.add('show');
        
        // Animation performante
        requestAnimationFrame(() => {
          submenu.style.maxHeight = submenu.scrollHeight + 'px';
        });
      }

      /**
       * 📂 FERMETURE DE TOUS LES SOUS-MENUS
       */
      closeAllSubMenus() {
        const openSubmenus = this.megaMenu.querySelectorAll('.submenu.show');
        const expandedButtons = this.megaMenu.querySelectorAll('button[aria-expanded="true"]');
        
        openSubmenus.forEach(submenu => {
          submenu.classList.remove('show');
          submenu.style.maxHeight = '';
        });
        
        expandedButtons.forEach(button => {
          button.setAttribute('aria-expanded', 'false');
        });
      }

      /**
       * 🚪 FERMETURE EXTERNE
       */
      setupExternalClosing() {
        document.addEventListener('click', (e) => {
          if (window.innerWidth >= 768) return;
          
          const isInsideMenu = this.megaMenu.contains(e.target);
          const isBurger = this.burger.contains(e.target);
          
          if (!isInsideMenu && !isBurger && this.isMenuOpen) {
            this.closeMenu();
          }
        });
        
        document.addEventListener('keydown', (e) => {
          if (e.key === 'Escape' && this.isMenuOpen) {
            e.preventDefault();
            this.closeMenu();
          }
        });
      }

      /**
       * ♿ CONFIGURATION DE L'ACCESSIBILITÉ
       */
      setupAccessibility() {
        // Configuration ARIA
        this.burger.setAttribute('aria-haspopup', 'true');
        this.burger.setAttribute('aria-controls', 'megaMenu');
        
        // Labels pour les sous-menus
        const submenuButtons = this.megaMenu.querySelectorAll('button[data-submenu]');
        submenuButtons.forEach(button => {
          const submenuId = button.getAttribute('data-submenu');
          button.setAttribute('aria-controls', submenuId);
        });
      }

      /**
       * 🎯 FOCUS TRAP DANS LE MENU
       */
      setupFocusTrap() {
        this.megaMenu.addEventListener('keydown', (e) => {
          if (!this.isMenuOpen) return;
          
          const focusableElements = this.getFocusableElements();
          const firstElement = focusableElements[0];
          const lastElement = focusableElements[focusableElements.length - 1];
          
          if (e.key === 'Tab') {
            if (e.shiftKey) {
              if (document.activeElement === firstElement) {
                e.preventDefault();
                lastElement.focus();
              }
            } else {
              if (document.activeElement === lastElement) {
                e.preventDefault();
                firstElement.focus();
              }
            }
          }
        });
      }

      /**
       * 🎯 ÉLÉMENTS FOCUSABLES
       */
      getFocusableElements() {
        const selector = 'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])';
        return Array.from(this.megaMenu.querySelectorAll(selector))
          .filter(element => !element.hasAttribute('disabled') && element.offsetParent !== null);
      }

      /**
       * 🎯 FOCUS SUR LE PREMIER ÉLÉMENT
       */
      focusFirstMenuItem() {
        const firstFocusable = this.getFocusableElements()[0];
        if (firstFocusable) {
          setTimeout(() => firstFocusable.focus(), 100);
        }
      }

      /**
       * 🔧 ÉTAT INITIAL
       */
      setupInitialState() {
        // Vérification du scroll initial
        this.handleScroll();
        
        // Configuration du z-index dynamique
        this.updateZIndex();
        
        // 🔥 FIX: S'assurer que le mega-menu est correctement initialisé
        if (window.innerWidth < 768) {
          this.megaMenu.style.pointerEvents = 'none';
          this.megaMenu.style.zIndex = '-1';
        } else {
          this.megaMenu.style.pointerEvents = '';
          this.megaMenu.style.zIndex = '';
        }
      }

      /**
       * 🔍 RÉINITIALISATION DES STYLES RESPONSIVES
       */
      resetResponsiveStyles() {
        if (window.innerWidth >= 768) {
          // Desktop: réinitialisation des styles mobiles
          document.body.style.overflow = '';
          this.closeAllSubMenus();
          
          // 🔥 FIX: Réactivation du mega-menu sur desktop
          this.megaMenu.style.pointerEvents = '';
          this.megaMenu.style.zIndex = '';
        } else {
          // Mobile: s'assurer que le mega-menu est désactivé si fermé
          if (!this.isMenuOpen) {
            this.megaMenu.style.pointerEvents = 'none';
            this.megaMenu.style.zIndex = '-1';
          }
        }
      }

      /**
       * 🎚️ MISE À JOUR DU Z-INDEX
       */
      updateZIndex() {
        // S'assurer que l'en-tête reste au-dessus des autres éléments
        const maxZ = Math.max(
          ...Array.from(document.querySelectorAll('*')).map(el => 
            parseInt(window.getComputedStyle(el).zIndex) || 0
          )
        );
        
        if (maxZ >= 999) {
          this.header.style.zIndex = maxZ + 10;
          this.burger.style.zIndex = maxZ + 11;
          // Le mega-menu garde son z-index dynamique géré séparément
        }
      }

      /**
       * 🚀 THROTTLE HELPER
       */
      throttle(func, limit) {
        let inThrottle;
        return function() {
          const args = arguments;
          const context = this;
          if (!inThrottle) {
            func.apply(context, args);
            inThrottle = true;
            setTimeout(() => inThrottle = false, limit);
          }
        };
      }

      /**
       * 🚀 DEBOUNCE HELPER
       */
      debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
          const later = () => {
            clearTimeout(timeout);
            func(...args);
          };
          clearTimeout(timeout);
          timeout = setTimeout(later, wait);
        };
      }

      /**
       * 🧹 NETTOYAGE
       */
      destroy() {
        // Suppression des event listeners
        window.removeEventListener('scroll', this.handleScroll);
        window.removeEventListener('resize', this.handleResize);
        
        // Nettoyage des timers
        if (this.scrollTimer) clearTimeout(this.scrollTimer);
        if (this.resizeTimer) clearTimeout(this.resizeTimer);
        
        // Restauration des styles
        document.body.style.overflow = '';
        
        // 🔥 FIX: Nettoyage du mega-menu
        this.megaMenu.style.pointerEvents = '';
        this.megaMenu.style.zIndex = '';
        
        console.log('NimbaHeader: Nettoyé avec succès');
      }
    }

    /**
     * 🎬 INITIALISATION SÉCURISÉE
     */
    class NimbaHeaderInitializer {
      static init() {
        // Vérification de l'environnement
        if (typeof document === 'undefined' || typeof window === 'undefined') {
          console.error('NimbaHeader: Environnement non supporté');
          return;
        }

        // Initialisation avec gestion d'erreurs
        const initializeHeader = () => {
          try {
            // Éviter les doubles initialisations
            if (window.nimbaHeaderInstance) {
              window.nimbaHeaderInstance.destroy();
            }

            window.nimbaHeaderInstance = new NimbaHeader();

            // Prevention du zoom sur mobile
            NimbaHeaderInitializer.preventMobileZoom();

            // Optimisations performance
            NimbaHeaderInitializer.setupPerformanceOptimizations();

          } catch (error) {
            console.error('NimbaHeader: Erreur fatale lors de l\'initialisation:', error);
          }
        };

        // Initialisation selon l'état du DOM
        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', initializeHeader);
        } else {
          // DOM déjà chargé
          setTimeout(initializeHeader, 0);
        }
      }

      /**
       * 📱 PRÉVENTION DU ZOOM SUR MOBILE
       */
      static preventMobileZoom() {
        const inputs = document.querySelectorAll('input, select, textarea');
        const viewport = document.querySelector('meta[name="viewport"]');
        
        if (!viewport) return;
        
        const originalViewport = viewport.content;
        
        inputs.forEach(element => {
          element.addEventListener('focus', () => {
            if (window.innerWidth < 768 && element.getAttribute('type') !== 'range') {
              viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
            }
          }, { passive: true });
          
          element.addEventListener('blur', () => {
            viewport.content = originalViewport;
          }, { passive: true });
        });
      }

      /**
       * ⚡ OPTIMISATIONS PERFORMANCE
       */
      static setupPerformanceOptimizations() {
        // Préchargement des images critiques
        const criticalImages = ['img_traitee/logo2.jpg'];
        criticalImages.forEach(src => {
          const link = document.createElement('link');
          link.rel = 'preload';
          link.as = 'image';
          link.href = src;
          document.head.appendChild(link);
        });

        // Lazy loading pour les images non critiques
        const lazyImages = document.querySelectorAll('img[loading="lazy"]');
        if ('IntersectionObserver' in window && lazyImages.length) {
          const imageObserver = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
              if (entry.isIntersecting) {
                const img = entry.target;
                img.src = img.dataset.src || img.src;
                imageObserver.unobserve(img);
              }
            });
          });
          
          lazyImages.forEach(img => imageObserver.observe(img));
        }
      }
    }

    // 🚀 DÉMARRAGE AUTOMATIQUE
    NimbaHeaderInitializer.init();

    // 🔧 EXPOSITION GLOBALE POUR DEBUG (DÉVELOPPEMENT UNIQUEMENT)
    if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
      window.NimbaHeaderDebug = {
        getInstance: () => window.nimbaHeaderInstance,
        getState: () => ({
          isMenuOpen: window.nimbaHeaderInstance?.isMenuOpen,
          lastScrollY: window.nimbaHeaderInstance?.lastScrollY,
          scrollThreshold: window.nimbaHeaderInstance?.scrollThreshold
        }),
        toggleMenu: () => window.nimbaHeaderInstance?.handleBurgerClick({ preventDefault: () => {}, stopPropagation: () => {} }),
        // 🔥 FIX: Fonction debug pour tester le mega-menu
        testMegaMenuState: () => {
          const megaMenu = document.getElementById('megaMenu');
          return {
            zIndex: window.getComputedStyle(megaMenu).zIndex,
            pointerEvents: window.getComputedStyle(megaMenu).pointerEvents,
            opacity: window.getComputedStyle(megaMenu).opacity,
            display: window.getComputedStyle(megaMenu).display
          };
        },
        version: '2.0.0 - Bug mega-menu CORRIGÉ'
      };
      
      console.log('🔥 NimbaHeader: Bug du mega-menu corrigé - Debug disponible: window.NimbaHeaderDebug');
    }

    // 🛡️ PROTECTION CONTRE LES ERREURS GLOBALES
    window.addEventListener('error', (e) => {
      if (e.error && e.error.message && e.error.message.includes('NimbaHeader')) {
        console.error('NimbaHeader: Erreur capturée:', e.error);
        // Tentative de récupération
        setTimeout(() => {
          if (!window.nimbaHeaderInstance) {
            NimbaHeaderInitializer.init();
          }
        }, 1000);
      }
    });

    // 📊 MÉTRIQUES PERFORMANCE (OPTIONNEL)
    if ('performance' in window && 'mark' in window.performance) {
      window.performance.mark('nimba-header-init-start');
      
      // Marquer la fin après l'initialisation
      setTimeout(() => {
        window.performance.mark('nimba-header-init-end');
        try {
          window.performance.measure('nimba-header-init-duration', 'nimba-header-init-start', 'nimba-header-init-end');
        } catch (e) {
          // Mesure échouée, pas critique
        }
      }, 100);
    }