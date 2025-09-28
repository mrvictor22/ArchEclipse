#!/bin/bash

# Script para sincronización automática de fork con upstream
# Uso: ./sync-upstream-auto.sh
# Este script no requiere interacción del usuario

set -e

echo "🤖 Sincronización automática iniciada..."

# Verificar que estamos en un repositorio git
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: No estás en un repositorio Git"
    exit 1
fi

# Obtener la rama actual
CURRENT_BRANCH=$(git branch --show-current)
echo "📍 Rama actual: $CURRENT_BRANCH"

# Verificar si hay cambios no commiteados
if ! git diff-index --quiet HEAD --; then
    echo "⚠️  Hay cambios no commiteados detectados"
    echo "🔄 Guardando cambios temporalmente con stash..."
    
    # Crear stash con mensaje descriptivo
    STASH_MESSAGE="Auto-stash antes de sync upstream $(date '+%Y-%m-%d %H:%M:%S')"
    git stash push -m "$STASH_MESSAGE"
    STASHED=true
    echo "✅ Cambios guardados en stash"
else
    STASHED=false
fi

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

# Fetch upstream y origin
echo "📥 Obteniendo cambios del upstream y origin..."
git fetch upstream
git fetch origin

# Verificar si hay cambios en upstream
BEHIND_UPSTREAM=$(git rev-list --count HEAD..upstream/master)
if [ "$BEHIND_UPSTREAM" -eq 0 ]; then
    echo "✅ Tu fork ya está actualizado con upstream"
    
    # Verificar si origin está adelante
    BEHIND_ORIGIN=$(git rev-list --count HEAD..origin/master)
    if [ "$BEHIND_ORIGIN" -gt 0 ]; then
        echo "📥 Sincronizando con cambios de origin..."
        git merge origin/master --no-edit
        echo "✅ Sincronizado con origin"
    fi
    
    # Regresar a la rama original
    if [ "$CURRENT_BRANCH" != "master" ]; then
        git checkout "$CURRENT_BRANCH"
    fi
    exit 0
fi

echo "📊 Tu fork está $BEHIND_UPSTREAM commits atrás del upstream"

# Función para manejar conflictos de merge automáticamente
handle_merge_conflicts() {
    local source=$1
    echo "🔧 Intentando resolver conflictos automáticamente..."
    
    # Obtener lista de archivos en conflicto
    CONFLICT_FILES=$(git diff --name-only --diff-filter=U)
    
    if [ -z "$CONFLICT_FILES" ]; then
        echo "✅ No hay conflictos que resolver"
        return 0
    fi
    
    echo "📋 Archivos en conflicto:"
    echo "$CONFLICT_FILES" | sed 's/^/   - /'
    
    # Estrategia automática: aceptar cambios del source (upstream/origin)
    echo "🤖 Resolviendo automáticamente aceptando cambios de $source..."
    
    for file in $CONFLICT_FILES; do
        if [ "$source" = "upstream" ]; then
            # Aceptar cambios de upstream
            git checkout --theirs "$file"
        else
            # Aceptar cambios de origin
            git checkout --theirs "$file"
        fi
        git add "$file"
        echo "   ✅ Resuelto: $file"
    done
    
    # Completar el merge
    git commit --no-edit
    echo "✅ Conflictos resueltos y merge completado"
}

# Detectar automáticamente la mejor estrategia
LOCAL_COMMITS=$(git rev-list --count origin/master..HEAD 2>/dev/null || echo "0")
ORIGIN_COMMITS=$(git rev-list --count HEAD..origin/master 2>/dev/null || echo "0")

echo "📋 Análisis:"
echo "   - Commits locales no pusheados: $LOCAL_COMMITS"
echo "   - Commits en origin no locales: $ORIGIN_COMMITS"
echo "   - Commits nuevos en upstream: $BEHIND_UPSTREAM"

# Estrategia automática
if [ "$LOCAL_COMMITS" -eq 0 ] && [ "$ORIGIN_COMMITS" -eq 0 ]; then
    echo "🚀 Estrategia: Fast-forward merge (sin commits locales)"
    STRATEGY="merge"
    git merge upstream/master --ff-only
elif [ "$LOCAL_COMMITS" -gt 0 ] && [ "$ORIGIN_COMMITS" -eq 0 ]; then
    echo "🔄 Estrategia: Rebase (commits locales presentes)"
    STRATEGY="rebase"
    git rebase upstream/master
else
    echo "🔀 Estrategia: Merge (situación compleja)"
    STRATEGY="merge"
    # Primero sincronizar con origin si es necesario
    if [ "$ORIGIN_COMMITS" -gt 0 ]; then
        echo "📥 Sincronizando primero con origin..."
        if ! git merge origin/master --no-edit; then
            echo "⚠️  Conflictos detectados al mergear con origin"
            handle_merge_conflicts "origin"
        fi
    fi
    
    if ! git merge upstream/master --no-edit; then
        echo "⚠️  Conflictos detectados al mergear con upstream"
        handle_merge_conflicts "upstream"
    fi
fi

# Función mejorada para push automático
auto_push() {
    local max_retries=3
    local retry=0
    
    echo "📤 Subiendo cambios automáticamente..."
    
    while [ $retry -lt $max_retries ]; do
        # Intentar push normal primero
        if git push origin master; then
            echo "✅ Push exitoso"
            return 0
        fi
        
        echo "⚠️  Push falló (intento $((retry + 1))/$max_retries)"
        
        # Fetch origin para ver qué pasó
        git fetch origin master
        
        # Verificar la situación
        if git merge-base --is-ancestor HEAD origin/master; then
            # Estamos adelante, algo raro pasó, usar force-with-lease
            echo "🔄 Usando force-with-lease..."
            if git push origin master --force-with-lease; then
                echo "✅ Push con force-with-lease exitoso"
                return 0
            fi
        else
            # Origin tiene cambios que no tenemos
            echo "🔄 Origin tiene cambios nuevos, integrando..."
            
            if [ "$STRATEGY" = "rebase" ]; then
                git rebase origin/master
            else
                git merge origin/master --no-edit
            fi
        fi
        
        retry=$((retry + 1))
    done
    
    echo "❌ Error: No se pudo hacer push después de $max_retries intentos"
    echo "💡 Revisa manualmente: git log --oneline --graph --all"
    return 1
}

# Ejecutar push automático
if ! auto_push; then
    exit 1
fi

# Regresar a la rama original si era diferente
if [ "$CURRENT_BRANCH" != "master" ]; then
    echo "🔄 Regresando a rama $CURRENT_BRANCH..."
    git checkout "$CURRENT_BRANCH"
fi

# Restaurar cambios del stash si los había
if [ "$STASHED" = true ]; then
    echo "🔄 Restaurando cambios desde stash..."
    if git stash pop; then
        echo "✅ Cambios restaurados exitosamente"
    else
        echo "⚠️  Hay conflictos al restaurar el stash"
        echo "💡 Resuelve los conflictos manualmente y luego ejecuta: git stash drop"
    fi
fi

echo "✅ ¡Sincronización automática completada!"
if [ "$BEHIND_UPSTREAM" -gt 0 ]; then
    echo "📊 Cambios aplicados: $BEHIND_UPSTREAM commits de upstream"
    echo "🎯 Estrategia utilizada: $STRATEGY"
else
    echo "📊 No había cambios nuevos en upstream"
fi
