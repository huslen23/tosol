from django.contrib import admin

from .models import Property, PropertyImage, Favorite, District, Complex

class PropertyImageInline(admin.TabularInline):
    model = PropertyImage
    extra = 0

@admin.register(Property)
class PropertyAdmin(admin.ModelAdmin):
    list_display = ["title", "listing_type", "district", "price", "owner", "is_featured"]
    list_filter = ["listing_type", "property_type", "district"]
    search_fields = ["title", "location"]
    inlines = [PropertyImageInline]

admin.site.register(Favorite)
@admin.register(District)
class DistrictAdmin(admin.ModelAdmin):
    list_display = ["name", "description"]
    search_fields = ["name"]

    def save_model(self, request, obj, form, change):
        old_name = District.objects.get(pk=obj.pk).name if change else None
        super().save_model(request, obj, form, change)
        if old_name and old_name != obj.name:
            Property.objects.filter(district=old_name).update(district=obj.name)


@admin.register(Complex)
class ComplexAdmin(admin.ModelAdmin):
    list_display = ["name", "district", "address"]
    list_filter = ["district"]
    search_fields = ["name", "address"]

    def save_model(self, request, obj, form, change):
        super().save_model(request, obj, form, change)
        if change:
            obj.properties.update(district=obj.district.name)

