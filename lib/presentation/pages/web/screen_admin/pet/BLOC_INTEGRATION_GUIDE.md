# Hướng dẫn tích hợp Bloc vào PetsAdmin

## 🎯 Mục tiêu
Convert `pets_admin.dart` từ StatefulWidget + CRUD methods sang Bloc pattern để tách biệt Business Logic khỏi UI.

## ✅ Đã hoàn thành

### 1. Tạo Bloc Structure
```
lib/presentation/pages/web/screen_admin/pet/bloc/
├── bloc.dart           # ✅ Barrel export
├── pet_event.dart      # ✅ 8 events
├── pet_state.dart      # ✅ 7 states
└── pet_bloc.dart       # ✅ Business logic
```

### 2. Thêm i18n keys
✅ Đã thêm vào `app_vi.arb` và `app_en.arb`:
- `category`, `breed`, `price`, `age`, `years`, `gender`, `weight`
- `petDetails`, `addingPet`, `updatingPet`, `deletingPet`
- `addPetSuccess`, `updatePetSuccess`, `deletePetSuccess`
- `errorLoadingPets`, `errorAddingPet`, `errorUpdatingPet`, `errorDeletingPet`

### 3. Fix LayoutBuilder Error
✅ `pet_details_dialog.dart` đã được sửa từ `AlertDialog` sang `Dialog` + `ConstrainedBox`

### 4. Apply i18n
✅ `pet_details_dialog.dart` đã sử dụng i18n cho tất cả labels

## 🚀 Các bước tích hợp Bloc (TODO)

### Bước 1: Wrap PetsAdmin với BlocProvider

**Hiện tại:**
```dart
class PetsAdmin extends StatefulWidget {
  const PetsAdmin({super.key});

  @override
  State<PetsAdmin> createState() => _PetsState();
}
```

**Sau khi refactor:**
```dart
class PetsAdmin extends StatelessWidget {
  const PetsAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PetBloc()..add(const LoadPetsEvent()),
      child: const _PetsAdminView(),
    );
  }
}

class _PetsAdminView extends StatefulWidget {
  const _PetsAdminView();

  @override
  State<_PetsAdminView> createState() => _PetsAdminViewState();
}
```

### Bước 2: Thay thế StreamBuilder bằng BlocBuilder

**Hiện tại (line ~490):**
```dart
StreamBuilder<QuerySnapshot>(
  stream: petsCollection.snapshots(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Center(child: CircularProgressIndicator(...));
    }
    // ...
  },
)
```

**Sau khi refactor:**
```dart
BlocBuilder<PetBloc, PetState>(
  builder: (context, state) {
    if (state is PetLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
    
    if (state is PetError) {
      return EmptyState(
        label: state.message,
        icon: Icons.error_outline,
      );
    }
    
    if (state is PetLoaded) {
      final pets = state.filteredPets;
      
      if (pets.isEmpty) {
        return const EmptyState(
          label: 'No pets found',
          icon: Icons.pets_outlined,
        );
      }
      
      return LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth ~/ 320;
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount.clamp(1, 5),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 3 / 2,
            ),
            itemCount: pets.length,
            itemBuilder: (context, i) => PetCard(
              pet: pets[i],
              onEdit: () => _showPetDialog(pet: pets[i]),
              onDelete: () => _confirmDelete(pets[i].id),
              onTap: () => _showPetDetailsDialog(pets[i]),
            ),
          );
        },
      );
    }
    
    return const SizedBox.shrink();
  },
)
```

### Bước 3: Thêm BlocListener để show SnackBar

Wrap Scaffold với BlocListener:

```dart
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  
  return BlocListener<PetBloc, PetState>(
    listener: (context, state) {
      if (state is PetActionSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.green,
          ),
        );
      } else if (state is PetError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    },
    child: Scaffold(
      // ... existing Scaffold code
    ),
  );
}
```

### Bước 4: Thay filter/search logic bằng Bloc events

**Hiện tại:**
```dart
onSelected: (_) => setState(() => selectedCategory = c),
```

**Sau khi refactor:**
```dart
onSelected: (_) {
  context.read<PetBloc>().add(FilterPetsByCategoryEvent(c));
},
```

**Hiện tại:**
```dart
onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
```

**Sau khi refactor:**
```dart
onChanged: (v) {
  context.read<PetBloc>().add(SearchPetsEvent(v.trim().toLowerCase()));
},
```

### Bước 5: Xóa các CRUD methods và thay bằng Bloc events

**XÓA các methods sau (lines 57-383):**
- `uploadImage()`
- `_pickImage()` - GIỮ LẠI
- `addPet()`
- `callTrainAPI()`
- `updatePet()`
- `deletePet()`
- `addBreed()`
- `loadBreeds()`

**GIỮ LẠI:**
- `_snack()` - Có thể giữ hoặc dùng BlocListener
- `_input()` - Helper cho dialog
- `_showPetDialog()` - Dialog method
- `_showPetDetailsDialog()` - Dialog method
- `_showBulkPrintDialog()` - Dialog method
- `_confirmDelete()` - Confirmation dialog

### Bước 6: Update addPet() call

**Hiện tại (trong _showPetDialog):**
```dart
if (pet == null) {
  await addPet(newPet);
} else {
  await updatePet(newPet);
}
```

**Sau khi refactor:**
```dart
if (pet == null) {
  if (_imageBytes == null) {
    _snack('Vui lòng chọn ảnh');
    return;
  }
  context.read<PetBloc>().add(
    AddPetEvent(
      pet: newPet,
      imageBytes: _imageBytes!.toList(),
    ),
  );
} else {
  context.read<PetBloc>().add(
    UpdatePetEvent(
      pet: newPet,
      imageBytes: _imageBytes?.toList(),
    ),
  );
}
```

### Bước 7: Update deletePet() call

**Hiện tại:**
```dart
if (ok == true) deletePet(id);
```

**Sau khi refactor:**
```dart
if (ok == true) {
  final pet = // find pet by id from BlocBuilder state
  context.read<PetBloc>().add(
    DeletePetEvent(
      petId: id,
      imageUrl: pet.imageUrl,
    ),
  );
}
```

### Bước 8: Update loadBreeds() call

**Hiện tại:**
```dart
await loadBreeds(pickedCategory);
```

**Sau khi refactor:**
```dart
context.read<PetBloc>().add(LoadBreedsEvent(pickedCategory));

// Listen for BreedsLoaded state
BlocListener<PetBloc, PetState>(
  listener: (context, state) {
    if (state is BreedsLoaded) {
      setState(() {
        breedsList = state.breeds;
        selectedBreed = breedsList.isNotEmpty ? breedsList.first : null;
      });
    }
  },
  child: // dialog content
)
```

### Bước 9: Remove loading overlay

**XÓA:**
```dart
if (isLoading)
  Container(
    color: Colors.black38,
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(...),
        SizedBox(height: 8),
        Text('Đang xử lý...', ...),
      ],
    ),
  ),
```

**LÝ DO:** BlocBuilder đã handle loading state, không cần Stack overlay

### Bước 10: Update selectedCategory state

**Hiện tại:** `selectedCategory` là local state

**Sau khi refactor:** Get từ BlocBuilder
```dart
BlocBuilder<PetBloc, PetState>(
  builder: (context, state) {
    final selectedCategory = state is PetLoaded 
        ? state.selectedCategory 
        : 'All';
    
    return ChoiceChip(
      label: Text(c),
      selected: selectedCategory == c,
      onSelected: (_) {
        context.read<PetBloc>().add(FilterPetsByCategoryEvent(c));
      },
    );
  },
)
```

## 📊 Kết quả mong đợi

### Before (Current):
```
_PetsState
├── Local State (selectedCategory, _searchQuery, isLoading, pets list)
├── CRUD Methods (addPet, updatePet, deletePet, uploadImage, callTrainAPI)
├── Helper Methods (loadBreeds, addBreed, _pickImage)
├── UI Methods (_showPetDialog, _confirmDelete, etc.)
└── StreamBuilder from Firestore
```

### After (With Bloc):
```
_PetsAdminViewState
├── UI State Only (_imageBytes, breedsList, selectedBreed, selectedColor)
├── UI Methods (_showPetDialog, _confirmDelete, _pickImage)
└── BlocBuilder + BlocListener
    └── PetBloc handles all business logic
```

## 🎯 Lợi ích

1. **Testability**: Có thể test PetBloc riêng không cần UI
2. **Reusability**: Có thể dùng PetBloc ở nhiều screens
3. **Maintainability**: Business logic tách biệt, dễ debug
4. **Scalability**: Dễ thêm features mới vào Bloc
5. **Clean Code**: UI chỉ tập trung vào rendering

## 📝 Notes

- Giữ nguyên Dialog methods vì chúng chứa UI logic (form validation, etc.)
- `_imageBytes` vẫn là local state vì nó chỉ dùng trong dialog
- `breedsList`, `selectedBreed`, `selectedColor` giữ là local state vì chỉ dùng trong dialog
- Category filter và search query nên move vào Bloc state
- Loading state không cần Stack overlay, dùng BlocBuilder

## 🚦 Testing Checklist

Sau khi refactor, test các chức năng:

- [ ] Load danh sách pets
- [ ] Filter theo category
- [ ] Search theo tên
- [ ] Thêm pet mới (with image upload)
- [ ] Update pet (with/without new image)
- [ ] Xóa pet (delete image from Storage)
- [ ] Load breeds khi chọn category
- [ ] Show success/error messages
- [ ] QR code printing (single + bulk)
- [ ] Detail dialog
