#!/bin/bash

# Script para sincronizar fork con upstream
# Uso: ./sync-upstream.sh

set -e

echo "🔄 Sincronizando fork con upstream..."

# Verificar que estamos en un repositorio git
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: No estás en un repositorio Git"
    exit 1
fi

# Obtener la rama actual
CURRENT_BRANCH=$(git branch --show-current)
echo "📍 Rama actual: $CURRENT_BRANCH"

# Cambiar a master si no estamos ahí
if [ "$CURRENT_BRANCH" != "master" ]; then
    echo "🔄 Cambiando a rama master..."
    git checkout master
fi

# Verificar que upstream existe
if ! git remote get-url upstream > /dev/null 2>&1; then
    echo "❌ Error: Remote 'upstream' no configurado"
    echo "💡 Configúralo con: git remote add upstream https://github.com/AymanLyesri/ArchEclipse.git"
    exit 1
fi

# Fetch upstream
echo "📥 Obteniendo cambios del upstream..."
git fetch upstream

# Verificar si hay cambios
BEHIND=$(git rev-list --count HEAD..upstream/master)
if [ "$BEHIND" -eq 0 ]; then
    echo "✅ Tu fork ya está actualizado"
    exit 0
fi

echo "📊 Tu fork está $BEHIND commits atrás del upstream"

# Preguntar al usuario qué método usar
echo "¿Cómo quieres sincronizar?"
echo "1) Merge (preserva historial completo)"
echo "2) Rebase (historial más limpio)"
echo "3) Automático (detecta la mejor opción)"
read -p "Selecciona (1, 2 o 3): " CHOICE

case $CHOICE in
    1)
        echo "🔀 Haciendo merge..."
        git merge upstream/master --no-edit
        ;;
    2)
        echo "🔄 Haciendo rebase..."
        git rebase upstream/master
        ;;
    3)
        echo "🤖 Modo automático activado..."
        # Verificar si hay commits locales no pusheados
        LOCAL_COMMITS=$(git rev-list --count origin/master..HEAD 2>/dev/null || echo "0")
        
        if [ "$LOCAL_COMMITS" -eq 0 ]; then
            echo "📋 No hay commits locales, usando merge rápido..."
            CHOICE=1
            git merge upstream/master --no-edit
        else
            echo "📋 Hay $LOCAL_COMMITS commits locales, usando rebase para historial limpio..."
            CHOICE=2
            git rebase upstream/master
        fi
        ;;
    *)
        echo "❌ Opción inválida"
        exit 1
        ;;
esac

# Push changes
echo "📤 Subiendo cambios a tu fork..."

# Función para manejar push con reintentos
push_changes() {
    local method=$1
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if [ "$method" -eq 2 ]; then
            # Para rebase, usar force-with-lease
            if git push origin master --force-with-lease; then
                return 0
            fi
        else
            # Para merge, intentar push normal primero
            if git push origin master; then
                return 0
            fi
        fi
        
        # Si falla el push, intentar sincronizar con origin primero
        echo "⚠️  Push falló, sincronizando con origin remoto..."
        
        # Fetch origin para obtener cambios remotos
        git fetch origin master
        
        # Verificar si hay conflictos
        if git merge-base --is-ancestor HEAD origin/master; then
            # Nuestros cambios están adelante, usar force-with-lease
            echo "🔄 Usando force-with-lease para sobrescribir cambios remotos..."
            if git push origin master --force-with-lease; then
                return 0
            fi
        else
            # Hay cambios en origin que no tenemos
            echo "🔄 Integrando cambios de origin remoto..."
            
            if [ "$method" -eq 2 ]; then
                # Con rebase, hacer rebase sobre origin/master
                git rebase origin/master
            else
                # Con merge, hacer merge de origin/master
                git merge origin/master --no-edit
            fi
        fi
        
        retry=$((retry + 1))
        echo "🔄 Reintento $retry de $max_retries..."
    done
    
    echo "❌ Error: No se pudo hacer push después de $max_retries intentos"
    return 1
}

# Llamar a la función de push
if ! push_changes "$CHOICE"; then
    echo "💡 Sugerencia: Revisa manualmente los cambios con 'git log --oneline --graph'"
    exit 1
fi

# Regresar a la rama original si era diferente
if [ "$CURRENT_BRANCH" != "master" ]; then
    echo "🔄 Regresando a rama $CURRENT_BRANCH..."
    git checkout "$CURRENT_BRANCH"
fi

echo "✅ ¡Sincronización completada!"
echo "📊 Cambios aplicados: $BEHIND commits"
