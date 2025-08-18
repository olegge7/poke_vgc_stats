// Pokemon VGC Stats JavaScript
// Global variables
let globalPokemonData = {};
let usageChart;
let speedChart;
let allPokemonNames = [];
let pokedex = [];
let restrictedList = [];
let cachedChaosData = null;
let cachedMonth = null;
let cachedFormat = null;
let itemsGridInstance, movesGridInstance, abilitiesGridInstance, naturesGridInstance;

$(function() {
  // DOM element references
  const $monthSelect = $('#monthSelect');
  const $formatSelect = $('#formatSelect');
  const $loadDataBtn = $('#loadDataBtn');
  const $usageChartCtx = $('#usageChart')[0].getContext('2d');
  const $pokemonList = $('#pokemonList');
  const $sidebarPanel = $('#sidebarPanel');
  const $pokemonSearch = $('#pokemonSearch');
  const $usageChartsCollapse = $('#usageChartsCollapse');
  const $chevronIcon = $('#usageChartsToggleBtn .chevron-icon');
  const $pokemonDetailsPanel = $('#pokemonDetailsPanel');
  const $pokemonDetailsName = $('#pokemonDetailsName');
  const $pokemonDetailsLoading = $('#pokemonDetailsLoading');
  const $pokemonDetailsError = $('#pokemonDetailsError');
  const $speedChartContainer = $('#speed-chart-container');
  const $itemsGrid = $('#items-grid');
  const $movesGrid = $('#moves-grid');
  const $abilitiesGrid = $('#abilities-grid');
  const $naturesGrid = $('#natures-grid');
  const $usageChartsCardHeader = $('.card-header:has(#usageChartsToggleBtn)');

  // Initialize application
  initializeApp();

  // Event handlers
  $monthSelect.on('change', function() {
    fetchFormats($(this).val());
    updateLoadButtonState();
  });

  $formatSelect.on('change', function() {
    updateLoadButtonState();
  });

  $loadDataBtn.on('click', function() {
    fetchAndRenderData();
  });

  // Use event delegation to ensure the search works even when the element is initially hidden
  $(document).on('input', '#pokemonSearch', function() {
    filterPokemonList($(this).val());
  });

  // Chart collapse event handlers
  if ($usageChartsCollapse.length && $chevronIcon.length) {
    $usageChartsCollapse.on('show.bs.collapse', function() {
      $chevronIcon.css('transform', 'rotate(0deg)');
    });
    $usageChartsCollapse.on('hide.bs.collapse', function() {
      $chevronIcon.css('transform', 'rotate(-90deg)');
    });
    // Set initial state
    if ($usageChartsCollapse.hasClass('show')) {
      $chevronIcon.css('transform', 'rotate(0deg)');
    } else {
      $chevronIcon.css('transform', 'rotate(-90deg)');
    }
  }

  // Make the entire card-header clickable to toggle collapse
  $usageChartsCardHeader.on('click', function(e) {
    // Prevent double toggle if the button itself was clicked
    if ($(e.target).closest('#usageChartsToggleBtn').length > 0) return;
    $('#usageChartsToggleBtn').trigger('click');
  });

  // Functions
  function initializeApp() {
    // Fetch months on page load
    $.getJSON('/months', function(months) {
      months.reverse().forEach(function(month) {
        $monthSelect.append($('<option>').val(month).text(month));
      });
      if (months.length > 0) {
        $monthSelect.val(months[0]);
        fetchFormats(months[0]);
      }
    }).fail(function(xhr, status, error) {
      alert('Failed to fetch months: ' + error);
    });

    // Fetch Pokedex.json on page load
    fetch('/pokedex.json')
      .then(res => res.json())
      .then(data => { pokedex = data; });

    // Fetch restricted_pokemon.json on page load
    fetch('/restricted_pokemon.json')
      .then(res => res.json())
      .then(data => { restrictedList = data; });
  }

  function fetchFormats(month) {
    $formatSelect.empty();
    $.getJSON(`/formats?month=${month}`, function(formats) {
      formats.forEach(function(format) {
        $formatSelect.append($('<option>').val(format).text(format));
      });
      if (formats.length > 0) {
        $formatSelect.val(formats[0]);
      }
      updateLoadButtonState();
    }).fail(function(xhr, status, error) {
      alert('Failed to fetch formats: ' + error);
    });
  }

  function updateLoadButtonState() {
    $loadDataBtn.prop('disabled', !($monthSelect.val() && $formatSelect.val()));
  }

  function fetchAndRenderData() {
    const month = $monthSelect.val();
    const format = $formatSelect.val();
    if (!month || !format) return;
    $.getJSON(`/data?month=${month}&format=${format}`, function(data) {
      if (data.error) {
        alert(data.error);
        return;
      }
      globalPokemonData = data.data;
      cachedChaosData = data.data;
      cachedMonth = month;
      cachedFormat = format;
      
      // Use pre-calculated usage charts data from backend
      renderUsageChartsFromBackend(data.usage_charts);
      renderPokemonListFromBackend(data.pokemon_list);
      
      // Show sidebar and clear search
      $sidebarPanel.show();
      $pokemonSearch.val('');
      // Show the usage charts card and expand the collapse
      $('#usageChartsCardWrapper').show();
      let collapse = bootstrap.Collapse.getOrCreateInstance($('#usageChartsCollapse')[0]);
      collapse.show();
    });
  }

  function renderUsageChartsFromBackend(chartsData) {
    // Render regular chart
    if (usageChart) usageChart.destroy();
    usageChart = new Chart($usageChartCtx, {
      type: 'bar',
      data: {
        labels: chartsData.regular.labels,
        datasets: [{
          label: 'Usage %',
          data: chartsData.regular.values,
          backgroundColor: 'rgba(54, 162, 235, 0.5)',
          borderColor: 'rgba(54, 162, 235, 1)',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: { display: false },
          title: {
            display: true,
            text: 'Top 12 Pokémon Usage % (Non-Restricted)'
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            title: { display: true, text: 'Usage %' }
          }
        }
      }
    });

    // Handle restricted chart
    const $usageChartCol = $('#usageChartCol');
    const $restrictedChartDiv = $('#restrictedChartDiv');
    const $restrictedPairsChartDiv = $('#restrictedPairsChartDiv');
    
    if (!chartsData.restricted.labels.length) {
      $usageChartCol.removeClass('col-md-6').addClass('col-12');
      $restrictedChartDiv.hide();
      $restrictedPairsChartDiv.hide();
    } else {
      $usageChartCol.removeClass('col-12').addClass('col-md-6');
      $restrictedChartDiv.show();
      $restrictedChartDiv.empty();
      const $canvas = $('<canvas id="restrictedChart" height="100"></canvas>');
      $restrictedChartDiv.append($canvas);
      const restrictedChartCtx = $canvas[0].getContext('2d');
      
      if (window.restrictedChart && typeof window.restrictedChart.destroy === 'function') {
        window.restrictedChart.destroy();
      }
      window.restrictedChart = new Chart(restrictedChartCtx, {
        type: 'bar',
        data: {
          labels: chartsData.restricted.labels,
          datasets: [{
            label: 'Usage %',
            data: chartsData.restricted.values,
            backgroundColor: 'rgba(255, 99, 132, 0.5)',
            borderColor: 'rgba(255, 99, 132, 1)',
            borderWidth: 1
          }]
        },
        options: {
          responsive: true,
          plugins: {
            legend: { display: false },
            title: {
              display: true,
              text: 'Top 8 Restricted Pokémon Usage %'
            }
          },
          scales: {
            y: {
              beginAtZero: true,
              title: { display: true, text: 'Usage %' }
            }
          }
        }
      });

      // Render restricted pairs chart
      if (chartsData.pairs.labels.length) {
        $restrictedPairsChartDiv.show();
        if (window.restrictedPairsChart && typeof window.restrictedPairsChart.destroy === 'function') {
          window.restrictedPairsChart.destroy();
        }
        const pairsCtx = document.getElementById('restrictedPairsChart').getContext('2d');
        window.restrictedPairsChart = new Chart(pairsCtx, {
          type: 'bar',
          data: {
            labels: chartsData.pairs.labels,
            datasets: [{
              label: 'Usage %',
              data: chartsData.pairs.values,
              backgroundColor: 'rgba(54, 162, 100, 0.7)',
              borderColor: 'rgba(54, 162, 100, 1)',
              borderWidth: 1
            }]
          },
          options: {
            responsive: true,
            plugins: {
              legend: { display: false },
              title: {
                display: true,
                text: 'Top 8 Restricted Pokemon Pairs Usage %'
              }
            },
            scales: {
              y: {
                beginAtZero: true,
                title: { display: true, text: 'Usage %' }
              }
            }
          }
        });
      } else {
        $restrictedPairsChartDiv.hide();
      }
    }
  }

  function renderPokemonListFromBackend(pokemonList) {
    $pokemonList.empty();
    allPokemonNames = pokemonList.map(pokemon => pokemon.name);
    
    pokemonList.forEach(pokemon => {
      const $li = $('<li>').addClass('list-group-item list-group-item-action d-flex justify-content-between align-items-center');
      const $nameSpan = $('<span>').addClass('pokemon-name').text(pokemon.name);
      const $badge = $('<span>')
        .addClass('badge rounded-pill')
        .addClass(pokemon.is_restricted ? '' : 'bg-primary')
        .css(pokemon.is_restricted ? { backgroundColor: '#ff6384', color: '#fff' } : {})
        .text(`${pokemon.usage_percentage}%`);
      $li.append($nameSpan, $badge);
      $li.css('cursor', 'pointer');
      $li.on('click', function() {
        fetchAndRenderPokemonDetails(pokemon.name);
      });
      $pokemonList.append($li);
    });
  }

  function showLoading() {
    $pokemonDetailsLoading.show();
    $pokemonDetailsError.hide();
  }

  function showError(msg) {
    $pokemonDetailsLoading.hide();
    $pokemonDetailsError.text(msg).show();
  }

  function clearMessages() {
    $pokemonDetailsLoading.hide();
    $pokemonDetailsError.hide();
  }

  function fetchAndRenderPokemonDetails(name) {
    const month = $monthSelect.val();
    const format = $formatSelect.val();
    if (!month || !format || !name) return;
    
    $pokemonDetailsPanel.hide();
    showLoading();
    
    // Always fetch from backend - all calculations are done server-side now
    $.getJSON(`/pokemon_details?month=${encodeURIComponent(month)}&format=${encodeURIComponent(format)}&name=${encodeURIComponent(name)}`)
      .done(function(data) {
        if (data.error) {
          showError(data.error);
          $pokemonDetailsPanel.hide();
          return;
        }
        clearMessages();
        renderPokemonDetailsFromApi(name, data);
      })
      .fail(function() {
        showError('Failed to load details.');
        $pokemonDetailsPanel.hide();
      });
  }

  function renderPokemonDetailsFromApi(name, data) {
    $pokemonDetailsPanel.show();
    $pokemonDetailsName.text(name);
    // Fully clear previous grids (remove all .gridjs elements)
    if (window.itemsGridInstance) window.itemsGridInstance.destroy();
    if (window.movesGridInstance) window.movesGridInstance.destroy();
    if (window.abilitiesGridInstance) window.abilitiesGridInstance.destroy();
    if (window.naturesGridInstance) window.naturesGridInstance.destroy();
    [$itemsGrid, $movesGrid, $abilitiesGrid, $naturesGrid].forEach($el => {
      $el.empty();
      $el.siblings('.gridjs').remove();
      $el.find('.gridjs').remove();
    });
    $speedChartContainer.hide();
    $('#attack-chart-container').hide();
    $('#defense-chart-container').hide();
    $('#spatk-chart-container').hide();
    $('#spdef-chart-container').hide();
    $('#hp-chart-container').hide();
    
    // Render grids
    if (data.items && data.items.length > 0) {
      window.itemsGridInstance = new gridjs.Grid({
        columns: ['Item', '%'],
        data: data.items,
        style: {
          table: { 'font-size': '0.9rem' },
          th: { 'text-align': 'left' },
          td: { 'text-align': 'left' }
        }
      }).render($itemsGrid[0]);
    } else {
      window.itemsGridInstance = null;
    }
    
    if (data.moves && data.moves.length > 0) {
      window.movesGridInstance = new gridjs.Grid({
        columns: ['Move', '%'],
        data: data.moves,
        style: {
          table: { 'font-size': '0.9rem' },
          th: { 'text-align': 'left' },
          td: { 'text-align': 'left' }
        }
      }).render($movesGrid[0]);
    } else {
      window.movesGridInstance = null;
    }
    
    if (data.abilities && data.abilities.length > 0) {
      window.abilitiesGridInstance = new gridjs.Grid({
        columns: ['Ability', '%'],
        data: data.abilities,
        style: {
          table: { 'font-size': '0.9rem' },
          th: { 'text-align': 'left' },
          td: { 'text-align': 'left' }
        }
      }).render($abilitiesGrid[0]);
    } else {
      window.abilitiesGridInstance = null;
    }
    
    if (data.natures && data.natures.length > 0) {
      window.naturesGridInstance = new gridjs.Grid({
        columns: ['Nature', 'Usage %', 'Common Spreads'],
        data: data.natures.map(([nature, pct, spreads]) => [nature, pct, gridjs.html(spreads)]),
        style: {
          table: { 'font-size': '0.9rem' },
          th: { 'text-align': 'left' },
          td: { 'text-align': 'left' }
        }
      }).render($naturesGrid[0]);
    } else {
      window.naturesGridInstance = null;
    }
    
    // Stat Distributions tab
    if (data.speed_distribution && data.speed_distribution.length > 0) {
      $speedChartContainer.show();
      if (window.speedChart && typeof window.speedChart.destroy === 'function') {
        window.speedChart.destroy();
      }
      setTimeout(() => {
        renderSpeedChartFromApi(data.speed_distribution);
      }, 100);
    } else {
      $speedChartContainer.hide();
    }
    
    if (data.attack_distribution && data.attack_distribution.length > 0) {
      $('#attack-chart-container').show();
      if (window.attackChart && typeof window.attackChart.destroy === 'function') {
        window.attackChart.destroy();
      }
      setTimeout(() => {
        renderAttackChartFromApi(data.attack_distribution);
      }, 100);
    } else {
      $('#attack-chart-container').hide();
    }
    
    if (data.defense_distribution && data.defense_distribution.length > 0) {
      $('#defense-chart-container').show();
      if (window.defenseChart && typeof window.defenseChart.destroy === 'function') {
        window.defenseChart.destroy();
      }
      setTimeout(() => {
        renderDefenseChartFromApi(data.defense_distribution);
      }, 100);
    } else {
      $('#defense-chart-container').hide();
    }
    
    if (data.sp_atk_distribution && data.sp_atk_distribution.length > 0) {
      $('#spatk-chart-container').show();
      if (window.spatkChart && typeof window.spatkChart.destroy === 'function') {
        window.spatkChart.destroy();
      }
      setTimeout(() => {
        renderSpAtkChartFromApi(data.sp_atk_distribution);
      }, 100);
    } else {
      $('#spatk-chart-container').hide();
    }
    
    if (data.sp_def_distribution && data.sp_def_distribution.length > 0) {
      $('#spdef-chart-container').show();
      if (window.spdefChart && typeof window.spdefChart.destroy === 'function') {
        window.spdefChart.destroy();
      }
      setTimeout(() => {
        renderSpDefChartFromApi(data.sp_def_distribution);
      }, 100);
    } else {
      $('#spdef-chart-container').hide();
    }
    
    if (data.hp_distribution && data.hp_distribution.length > 0) {
      $('#hp-chart-container').show();
      if (window.hpChart && typeof window.hpChart.destroy === 'function') {
        window.hpChart.destroy();
      }
      setTimeout(() => {
        renderHpChartFromApi(data.hp_distribution);
      }, 100);
    } else {
      $('#hp-chart-container').hide();
    }
  }

  function renderSpeedChartFromApi(speed_distribution) {
    if (speedChart) speedChart.destroy();
    const ctx = document.getElementById('speedChart').getContext('2d');
    const labels = speed_distribution.map(([spd, _]) => spd);
    const dataArr = speed_distribution.map(([_, pct]) => parseFloat(pct));
    speedChart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: 'Usage %',
          data: dataArr,
          backgroundColor: 'rgba(255, 99, 132, 0.5)',
          borderColor: 'rgba(255, 99, 132, 1)',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: { display: false },
          title: {
            display: true,
            text: 'Speed Distribution'
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            title: { display: true, text: 'Usage %' }
          },
          x: {
            title: { display: true, text: 'Speed' }
          }
        }
      }
    });
  }

  function renderAttackChartFromApi(attack_distribution) {
    if (window.attackChart && typeof window.attackChart.destroy === 'function') {
      window.attackChart.destroy();
    }
    const ctx = document.getElementById('attackChart').getContext('2d');
    const labels = attack_distribution.map(([atk, _]) => atk);
    const dataArr = attack_distribution.map(([_, pct]) => parseFloat(pct));
    window.attackChart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: 'Usage %',
          data: dataArr,
          backgroundColor: 'rgba(255, 159, 64, 0.5)',
          borderColor: 'rgba(255, 159, 64, 1)',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: { display: false },
          title: {
            display: true,
            text: 'Attack Distribution'
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            title: { display: true, text: 'Usage %' }
          },
          x: {
            title: { display: true, text: 'Attack' }
          }
        }
      }
    });
  }

  function renderDefenseChartFromApi(defense_distribution) {
    if (window.defenseChart && typeof window.defenseChart.destroy === 'function') {
      window.defenseChart.destroy();
    }
    const ctx = document.getElementById('defenseChart').getContext('2d');
    const labels = defense_distribution.map(([def, _]) => def);
    const dataArr = defense_distribution.map(([_, pct]) => parseFloat(pct));
    window.defenseChart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: 'Usage %',
          data: dataArr,
          backgroundColor: 'rgba(75, 192, 192, 0.5)',
          borderColor: 'rgba(75, 192, 192, 1)',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: { display: false },
          title: {
            display: true,
            text: 'Defense Distribution'
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            title: { display: true, text: 'Usage %' }
          },
          x: {
            title: { display: true, text: 'Defense' }
          }
        }
      }
    });
  }

  function renderSpAtkChartFromApi(spatk_distribution) {
    if (window.spatkChart && typeof window.spatkChart.destroy === 'function') {
      window.spatkChart.destroy();
    }
    const ctx = document.getElementById('spatkChart').getContext('2d');
    const labels = spatk_distribution.map(([spa, _]) => spa);
    const dataArr = spatk_distribution.map(([_, pct]) => parseFloat(pct));
    window.spatkChart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: 'Usage %',
          data: dataArr,
          backgroundColor: 'rgba(153, 102, 255, 0.5)',
          borderColor: 'rgba(153, 102, 255, 1)',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: { display: false },
          title: {
            display: true,
            text: 'Special Attack Distribution'
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            title: { display: true, text: 'Usage %' }
          },
          x: {
            title: { display: true, text: 'Sp. Atk' }
          }
        }
      }
    });
  }

  function renderSpDefChartFromApi(spdef_distribution) {
    if (window.spdefChart && typeof window.spdefChart.destroy === 'function') {
      window.spdefChart.destroy();
    }
    const ctx = document.getElementById('spdefChart').getContext('2d');
    const labels = spdef_distribution.map(([spd, _]) => spd);
    const dataArr = spdef_distribution.map(([_, pct]) => parseFloat(pct));
    window.spdefChart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: 'Usage %',
          data: dataArr,
          backgroundColor: 'rgba(255, 205, 86, 0.5)',
          borderColor: 'rgba(255, 205, 86, 1)',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: { display: false },
          title: {
            display: true,
            text: 'Special Defense Distribution'
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            title: { display: true, text: 'Usage %' }
          },
          x: {
            title: { display: true, text: 'Sp. Def' }
          }
        }
      }
    });
  }

  function renderHpChartFromApi(hp_distribution) {
    if (window.hpChart && typeof window.hpChart.destroy === 'function') {
      window.hpChart.destroy();
    }
    const ctx = document.getElementById('hpChart').getContext('2d');
    const labels = hp_distribution.map(([hp, _]) => hp);
    const dataArr = hp_distribution.map(([_, pct]) => parseFloat(pct));
    window.hpChart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: 'Usage %',
          data: dataArr,
          backgroundColor: 'rgba(255, 99, 71, 0.5)',
          borderColor: 'rgba(255, 99, 71, 1)',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: { display: false },
          title: {
            display: true,
            text: 'HP Distribution'
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            title: { display: true, text: 'Usage %' }
          },
          x: {
            title: { display: true, text: 'HP' }
          }
        }
      }
    });
  }

  function filterPokemonList(query) {
    const filter = query.trim().toLowerCase();
    const $pokemonListCurrent = $('#pokemonList'); // Get a fresh reference
    $pokemonListCurrent.children().each(function() {
      const $nameSpan = $(this).children('.pokemon-name');
      const nameText = $nameSpan.text().trim().toLowerCase();
      if (nameText.includes(filter)) {
        $(this).removeClass('pokemon-hide');
      } else {
        $(this).addClass('pokemon-hide');
      }
    });
  }
});
